param(
    [ValidateSet("standard")]
    [string]$Profile = "standard",

    [switch]$VerifyOnly,

    [switch]$DryRun,

    [switch]$Relaunched
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$PlatformBootstrap = Join-Path $Root "bootstrap.ps1"

function Write-StageZero {
    param([string]$Status, [string]$Message)

    $Prefix = "[{0,-4}] Stage 0  " -f $Status
    $Continuation = " " * $Prefix.Length
    $Width = 72 - $Prefix.Length
    $Remaining = $Message

    while ($Remaining.Length -gt $Width) {
        $BreakAt = $Remaining.Substring(0, $Width).LastIndexOf(" ")
        if ($BreakAt -lt [math]::Floor($Width / 2)) { $BreakAt = $Width }

        Write-Host ($Prefix + $Remaining.Substring(0, $BreakAt).TrimEnd())
        $Remaining = $Remaining.Substring($BreakAt).TrimStart()
        $Prefix = $Continuation
    }

    Write-Host ($Prefix + $Remaining)
}

function Get-PwshPath {
    $Command = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($Command) { return $Command.Source }

    $Candidates = @(
        (Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\pwsh.exe")
    )

    foreach ($Candidate in $Candidates) {
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
            return $Candidate
        }
    }

    return $null
}

function Test-Executable {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    try {
        & $Path @Arguments | Out-Null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Test-IsAdministrator {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal $Identity
    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Install-PowerShellSeven {
    $NativeArchitecture = if ($env:PROCESSOR_ARCHITEW6432) {
        $env:PROCESSOR_ARCHITEW6432
    }
    else {
        $env:PROCESSOR_ARCHITECTURE
    }

    $Architecture = switch ($NativeArchitecture) {
        "AMD64" { "x64" }
        "ARM64" { "arm64" }
        default { throw "Unsupported Windows architecture: $_" }
    }

    $TemporaryRoot = Join-Path `
        ([IO.Path]::GetTempPath()) `
        ("larrybootstrap-stage0-" + [guid]::NewGuid().ToString("N"))

    New-Item -ItemType Directory -Path $TemporaryRoot | Out-Null

    try {
        Write-StageZero "INFO" "finding the latest stable PowerShell release"
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor
            [Net.SecurityProtocolType]::Tls12

        $Headers = @{ "User-Agent" = "LarryBootstrap-Stage0" }
        $Release = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest" `
            -Headers $Headers `
            -UseBasicParsing

        $Pattern = "^PowerShell-[0-9.]+-win-$Architecture\.msi$"
        $Asset = $Release.assets |
            Where-Object { $_.name -match $Pattern } |
            Select-Object -First 1

        if (-not $Asset) {
            throw "The latest stable release has no $Architecture MSI asset."
        }

        $InstallerPath = Join-Path $TemporaryRoot $Asset.name
        Write-StageZero "INFO" "downloading $($Asset.name) from PowerShell GitHub"
        Invoke-WebRequest `
            -Uri $Asset.browser_download_url `
            -Headers $Headers `
            -OutFile $InstallerPath `
            -UseBasicParsing

        $Signature = Get-AuthenticodeSignature -FilePath $InstallerPath
        if ($Signature.Status -ne "Valid") {
            throw "PowerShell MSI signature is $($Signature.Status), not Valid."
        }

        Write-StageZero "INFO" "installing PowerShell 7"
        $Process = Start-Process `
            -FilePath "$env:SystemRoot\System32\msiexec.exe" `
            -ArgumentList @(
                "/i", ('"{0}"' -f $InstallerPath), "/quiet", "/norestart",
                "USE_MU=1", "ENABLE_MU=1"
            ) `
            -Wait `
            -PassThru

        if ($Process.ExitCode -notin @(0, 3010)) {
            throw "PowerShell MSI failed with exit code $($Process.ExitCode)."
        }
    }
    finally {
        if (Test-Path -LiteralPath $TemporaryRoot) {
            Remove-Item `
                -LiteralPath $TemporaryRoot `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

function Get-WinGetPath {
    $Command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($Command) { return $Command.Source }

    $Alias = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path -LiteralPath $Alias -PathType Leaf) { return $Alias }

    return $null
}

function Update-CommandDiscovery {
    $MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$MachinePath;$UserPath"
}

function Get-WinGetStatus {
    Update-CommandDiscovery
    $Path = Get-WinGetPath
    if (-not $Path) {
        return [pscustomobject]@{ Healthy = $false; Path = $null }
    }

    try {
        $Version = @(& $Path --version 2>$null)
        if ($LASTEXITCODE -eq 0 -and $Version.Count -gt 0) {
            return [pscustomobject]@{ Healthy = $true; Path = $Path }
        }
    }
    catch {
        # A stale App Execution Alias can exist but fail when invoked.
    }

    return [pscustomobject]@{ Healthy = $false; Path = $Path }
}

function Install-WinGetRepairModule {
    Write-StageZero "INFO" "installing Microsoft's WinGet repair module"

    if (-not (Get-Command Install-PSResource -ErrorAction SilentlyContinue)) {
        throw (
            "PowerShell's bundled PSResourceGet module is unavailable; " +
            "cannot install the Microsoft WinGet repair module."
        )
    }

    if (-not (Get-PSResourceRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
        Register-PSResourceRepository -PSGallery
    }

    Install-PSResource `
        -Name Microsoft.WinGet.Client `
        -Repository PSGallery `
        -Scope CurrentUser `
        -TrustRepository `
        -AcceptLicense `
        -Quiet

    Import-Module Microsoft.WinGet.Client -Force
}

Write-Host ""
Write-StageZero "INFO" "checking bootstrap prerequisites"

$PwshPath = Get-PwshPath
$PwshHealthy = $PwshPath -and (
    Test-Executable -Path $PwshPath -Arguments @(
        "-NoLogo", "-NoProfile", "-Command",
        "exit [int](`$PSVersionTable.PSVersion.Major -lt 7)"
    )
)
$WinGetStatus = Get-WinGetStatus
$WinGetPath = $WinGetStatus.Path
$WinGetHealthy = $WinGetStatus.Healthy

if ($DryRun -and (-not $PwshHealthy -or -not $WinGetHealthy)) {
    if ($PwshHealthy) {
        Write-StageZero "OK" "PowerShell 7 is usable at $PwshPath"
    }
    else {
        Write-StageZero "PLAN" "would install PowerShell 7"
    }

    if ($WinGetHealthy) {
        Write-StageZero "OK" "WinGet is usable at $WinGetPath"
    }
    else {
        Write-StageZero "PLAN" "would install or repair WinGet"
    }

    Write-StageZero "INFO" "normal dry run cannot continue until prerequisites exist"
    exit 1
}

if (-not $PwshHealthy) {
    if (-not (Test-IsAdministrator)) {
        throw "PowerShell 7 installation requires an elevated Administrator shell."
    }

    Install-PowerShellSeven
    $PwshPath = Get-PwshPath
    if (-not $PwshPath -or -not (
        Test-Executable -Path $PwshPath -Arguments @(
            "-NoLogo", "-NoProfile", "-Command",
            "exit [int](`$PSVersionTable.PSVersion.Major -lt 7)"
        )
    )) {
        throw "PowerShell 7 installation completed, but pwsh.exe is not usable."
    }
}

Write-StageZero "OK" "PowerShell 7 is usable at $PwshPath"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    if ($Relaunched) { throw "Stage 0 PowerShell relaunch loop detected." }

    $QuotedScript = '"{0}"' -f $MyInvocation.MyCommand.Path.Replace('"', '\"')
    $Arguments = @(
        "-NoExit"
        "-NoLogo"
        "-NoProfile"
        "-ExecutionPolicy"
        "Bypass"
        "-File"
        $QuotedScript
        "-Profile"
        $Profile
        "-Relaunched"
    )
    if ($VerifyOnly) { $Arguments += "-VerifyOnly" }
    if ($DryRun) { $Arguments += "-DryRun" }

    Write-StageZero "INFO" "opening an elevated PowerShell 7 bootstrap console"
    Start-Process `
        -FilePath $PwshPath `
        -ArgumentList $Arguments `
        -WorkingDirectory (Split-Path -Parent $Root) `
        -Verb RunAs `
        -WindowStyle Normal | Out-Null

    Write-StageZero "OK" "handoff started; closing Windows PowerShell Stage 0"
    exit 0
}

if (-not $WinGetHealthy) {
    if (-not (Test-IsAdministrator)) {
        throw "WinGet repair requires an elevated Administrator shell."
    }

    # Re-test after refreshing PATH and App Execution Alias discovery. A
    # healthy current App Installer must never be repaired merely because an
    # earlier process observed stale command state.
    $WinGetStatus = Get-WinGetStatus
    $WinGetPath = $WinGetStatus.Path
    $WinGetHealthy = $WinGetStatus.Healthy

    if (-not $WinGetHealthy) {
        Install-WinGetRepairModule

        Write-StageZero "INFO" "installing or updating WinGet for all users"
        try {
            Repair-WinGetPackageManager -AllUsers -Latest | Out-Null
        }
        catch {
            Write-StageZero "WARN" "WinGet update reported an error; re-checking usability"
        }

        $WinGetStatus = Get-WinGetStatus
        $WinGetPath = $WinGetStatus.Path
        $WinGetHealthy = $WinGetStatus.Healthy
    }

    if (-not $WinGetHealthy) {
        Write-StageZero "INFO" "attempting forced WinGet recovery"
        try {
            Repair-WinGetPackageManager -AllUsers -Force -Latest | Out-Null
        }
        catch {
            Write-StageZero "WARN" "forced recovery reported an error; re-checking usability"
        }

        $WinGetStatus = Get-WinGetStatus
        $WinGetPath = $WinGetStatus.Path
        $WinGetHealthy = $WinGetStatus.Healthy
    }

    if (-not $WinGetHealthy) {
        throw "WinGet installation or recovery completed, but winget.exe is not usable."
    }
}

Write-StageZero "OK" "WinGet is usable at $WinGetPath"

$Arguments = @("-Profile", $Profile)
if ($VerifyOnly) { $Arguments += "-VerifyOnly" }
if ($DryRun) { $Arguments += "-DryRun" }

& $PwshPath -NoLogo -NoProfile -File $PlatformBootstrap @Arguments
exit $LASTEXITCODE
