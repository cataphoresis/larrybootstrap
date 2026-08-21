Set-StrictMode -Version Latest

# LarryBootstrap's cross-platform terminal presentation contract is 72 columns.
# This stays within a conventional 80-column terminal while leaving enough room
# for Windows paths and a fixed right-side status column.
$script:LarryPanelWidth = 72
$script:LarryPanelInnerWidth = $script:LarryPanelWidth - 4

function Split-LarryText {
    param(
        [AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][int]$Width
    )

    $Remaining = $Text.Trim()
    if ($Remaining.Length -eq 0) { return ,"" }

    $Lines = [Collections.Generic.List[string]]::new()
    while ($Remaining.Length -gt $Width) {
        $Candidate = $Remaining.Substring(0, $Width)
        $BreakAt = $Candidate.LastIndexOf(" ")
        if ($BreakAt -lt [math]::Floor($Width / 2)) {
            $SeparatorAt = [math]::Max(
                [math]::Max($Candidate.LastIndexOf("\"), $Candidate.LastIndexOf("/")),
                $Candidate.LastIndexOf("-")
            )
            if ($SeparatorAt -ge [math]::Floor($Width / 2)) {
                $BreakAt = $SeparatorAt + 1
            }
            else {
                $BreakAt = $Width
            }
        }
        $Lines.Add($Remaining.Substring(0, $BreakAt).TrimEnd())
        $Remaining = $Remaining.Substring($BreakAt).TrimStart()
    }
    $Lines.Add($Remaining)
    return $Lines.ToArray()
}

function Write-LarryBorder {
    Write-Host ("+" + ("-" * ($script:LarryPanelWidth - 2)) + "+") -ForegroundColor DarkCyan
}

function Write-LarryPanelLine {
    param(
        [AllowEmptyString()][string]$Text,
        [string]$Status = "",
        [ConsoleColor]$StatusColor = [ConsoleColor]::Gray
    )

    $StatusWidth = 6
    $BodyWidth = $script:LarryPanelInnerWidth - $StatusWidth - 1
    $Lines = @(Split-LarryText -Text $Text -Width $BodyWidth)

    for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
        $Marker = if ($Index -eq 0) { $Status } else { "" }
        Write-Host "| " -ForegroundColor DarkCyan -NoNewline
        Write-Host ("{0,-$BodyWidth}" -f $Lines[$Index]) -NoNewline
        Write-Host " " -NoNewline
        Write-Host ("{0,$StatusWidth}" -f $Marker) -ForegroundColor $StatusColor -NoNewline
        Write-Host " |" -ForegroundColor DarkCyan
    }
}

function Write-LarryStatus {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][ConsoleColor]$Color
    )

    Write-LarryPanelLine -Text ("{0}  {1}" -f $Label, $Message) -Status $Status -StatusColor $Color
}

function Write-Section {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host ""
    Write-LarryBorder
    foreach ($Line in @(Split-LarryText -Text $Title -Width $script:LarryPanelInnerWidth)) {
        Write-Host "| " -ForegroundColor DarkCyan -NoNewline
        Write-Host ("{0,-$($script:LarryPanelInnerWidth)}" -f $Line) -ForegroundColor Cyan -NoNewline
        Write-Host " |" -ForegroundColor DarkCyan
    }
    Write-LarryBorder
}

function Write-OK {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-LarryStatus -Label $Label -Message $Message -Status "[ OK ]" -Color Green
}

function Write-Warn {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-LarryStatus -Label $Label -Message $Message -Status "[WARN]" -Color Yellow
}

function Write-Fail {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-LarryStatus -Label $Label -Message $Message -Status "[FAIL]" -Color Red
}

function Write-InfoLine {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-LarryStatus -Label $Label -Message $Message -Status "[INFO]" -Color Blue
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Test-CommandAvailable {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return $null -ne (
        Get-Command $Name -ErrorAction SilentlyContinue
    )
}

function Test-InternetConnection {
    param(
        [string]$HostName = "www.microsoft.com",
        [int]$Port = 443,
        [int]$TimeoutMilliseconds = 3000
    )

    try {
        $client = [System.Net.Sockets.TcpClient]::new()

        $task = $client.ConnectAsync($HostName, $Port)

        if (-not $task.Wait($TimeoutMilliseconds)) {
            $client.Dispose()
            return $false
        }

        $client.Dispose()
        return $true
    }
    catch {
        return $false
    }
}

function New-TimestampedReport {
    param(
        [Parameter(Mandatory)]
        [string]$RootDirectory,

        [Parameter(Mandatory)]
        [string]$Prefix,

        [switch]$DryRun
    )

    if ($DryRun) {
        return $null
    }

    $reportDirectory = Join-Path $RootDirectory "reports"
    New-Item -ItemType Directory -Force $reportDirectory | Out-Null

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    return Join-Path `
        $reportDirectory `
        "$Prefix-$timestamp.txt"
}

function Invoke-BootstrapArtifactRetention {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootDirectory,

        [ValidateRange(1, 100)]
        [int]$KeepPerModule = 3,

        [switch]$DryRun
    )

    if ($DryRun) {
        return
    }

    $TimestampPattern =
        '^(?<Prefix>.+)-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$'

    foreach ($ArtifactDirectoryName in @("reports", "backups")) {
        $ArtifactDirectory = Join-Path $RootDirectory $ArtifactDirectoryName

        if (-not (Test-Path -LiteralPath $ArtifactDirectory -PathType Container)) {
            continue
        }

        $Artifacts = Get-ChildItem -LiteralPath $ArtifactDirectory -Force |
            Where-Object { $_.Name -ne ".gitkeep" } |
            ForEach-Object {
                $ComparableName = if ($_.PSIsContainer) {
                    $_.Name
                }
                else {
                    [IO.Path]::GetFileNameWithoutExtension($_.Name)
                }

                if ($ComparableName -match $TimestampPattern) {
                    [pscustomobject]@{
                        Artifact = $_
                        Prefix   = $Matches.Prefix
                    }
                }
            }

        foreach ($Group in $Artifacts | Group-Object Prefix) {
            $Group.Group |
                Sort-Object { $_.Artifact.LastWriteTimeUtc } -Descending |
                Select-Object -Skip $KeepPerModule |
                ForEach-Object {
                    Remove-Item -LiteralPath $_.Artifact.FullName -Recurse -Force
                }
        }
    }
}

function Test-ApplicationPath {
    param(
        [Parameter(Mandatory)]
        [string[]]$Paths
    )

    foreach ($path in $Paths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

function Get-SystemVolumeInfo {
    [CmdletBinding()]
    param()

    $DriveLetter = $env:SystemDrive.TrimEnd(":")

    try {
        $Volume = Get-Volume `
            -DriveLetter $DriveLetter `
            -ErrorAction Stop

        return [pscustomobject]@{
            DriveLetter   = $DriveLetter
            Size          = $Volume.Size
            SizeRemaining = $Volume.SizeRemaining
        }
    }
    catch {
        $Drive = [IO.DriveInfo]::new("$DriveLetter`:\")

        return [pscustomobject]@{
            DriveLetter   = $DriveLetter
            Size          = $Drive.TotalSize
            SizeRemaining = $Drive.AvailableFreeSpace
        }
    }
}

function Get-WingetPackage {
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    if (-not (Test-CommandAvailable "winget")) {
        return $null
    }

    try {
        $output = winget list `
            --id $Id `
            --exact `
            --accept-source-agreements 2>$null

        if ($LASTEXITCODE -eq 0 -and $output -match [regex]::Escape($Id)) {
            return $output
        }
    }
    catch {
        return $null
    }

    return $null
}

function Get-PackageManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Package manifest not found: $Path"
    }

    $LineNumber = 0

    foreach ($Line in Get-Content -LiteralPath $Path) {
        $LineNumber++
        $TrimmedLine = $Line.Trim()

        # Ignore blank lines and comments.
        if (
            [string]::IsNullOrWhiteSpace($TrimmedLine) -or
            $TrimmedLine.StartsWith("#")
        ) {
            continue
        }

        $Fields = $TrimmedLine.Split("|")

        if ($Fields.Count -notin @(3, 4)) {
            throw (
                "Invalid manifest entry at line ${LineNumber}: " +
                "expected id|display|required[|context]"
            )
        }

        $Id = $Fields[0].Trim()
        $DisplayName = $Fields[1].Trim()
        $RequiredText = $Fields[2].Trim()
        $Context = if ($Fields.Count -eq 4) {
            $Fields[3].Trim().ToLowerInvariant()
        }
        else {
            "elevated"
        }

        if ([string]::IsNullOrWhiteSpace($Id)) {
            throw "Missing package ID at line $LineNumber."
        }

        if ([string]::IsNullOrWhiteSpace($DisplayName)) {
            throw "Missing display name at line $LineNumber."
        }

        $Required = $false

        if (-not [bool]::TryParse($RequiredText, [ref]$Required)) {
            throw (
                "Invalid required value at line ${LineNumber}: " +
                "'$RequiredText' must be true or false."
            )
        }

        if ($Context -notin @("elevated", "user")) {
            throw "Invalid context at line ${LineNumber}: $Context"
        }

        [pscustomobject]@{
            Id         = $Id
            DisplayName = $DisplayName
            Required    = $Required
            Context     = $Context
            LineNumber  = $LineNumber
        }
    }
}

function Test-WinGetPackageInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    try {
        $Output = winget list `
            --id $Id `
            --exact `
            --accept-source-agreements 2>$null

        return ($LASTEXITCODE -eq 0 -and $Output -match [regex]::Escape($Id))
    }
    catch {
        return $false
    }
}

function Get-WinGetVerificationDisposition {
    param(
        [Parameter(Mandatory)][pscustomobject]$Package,
        [Parameter(Mandatory)][bool]$Installed,
        [string[]]$DeferredPackageIds = @()
    )

    if ($Installed) { return "Installed" }
    if ($Package.Id -in $DeferredPackageIds) { return "Deferred" }
    if ($Package.Required) { return "RequiredMissing" }
    return "OptionalMissing"
}

function Invoke-WinGetPackageAsInteractiveUser {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PackageId)

    $Helper = Join-Path $PSScriptRoot "..\Invoke-UserWingetInstall.ps1"
    $Token = [guid]::NewGuid().ToString("N")
    $TaskName = "LarryBootstrap-UserInstall-$Token"
    $ResultPath = Join-Path $env:TEMP "$TaskName.result"
    $LogPath = Join-Path $env:TEMP "$TaskName.log"
    $UserId = "$env:USERDOMAIN\$env:USERNAME"
    $PwshPath = (Get-Command pwsh.exe -ErrorAction Stop).Source
    $ActionArguments = @(
        "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", ('"{0}"' -f $Helper),
        "-PackageId", ('"{0}"' -f $PackageId),
        "-ResultPath", ('"{0}"' -f $ResultPath),
        "-LogPath", ('"{0}"' -f $LogPath)
    ) -join " "

    try {
        $Action = New-ScheduledTaskAction `
            -Execute $PwshPath `
            -Argument $ActionArguments
        $Principal = New-ScheduledTaskPrincipal `
            -UserId $UserId `
            -LogonType Interactive `
            -RunLevel Limited
        $Settings = New-ScheduledTaskSettingsSet `
            -ExecutionTimeLimit (New-TimeSpan -Minutes 30) `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries

        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $Action `
            -Principal $Principal `
            -Settings $Settings `
            -Force | Out-Null
        Start-ScheduledTask -TaskName $TaskName

        $Deadline = (Get-Date).AddMinutes(30)
        while (-not (Test-Path -LiteralPath $ResultPath -PathType Leaf)) {
            if ((Get-Date) -ge $Deadline) {
                throw "Per-user WinGet install timed out after 30 minutes."
            }
            Start-Sleep -Seconds 2
        }

        $ExitCode = [int](Get-Content -LiteralPath $ResultPath -Raw)
        $Output = if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
            @(Get-Content -LiteralPath $LogPath)
        }
        else { @() }

        $ContextVerified = $Output -contains "[CONTEXT] Elevated=False"
        return [pscustomobject]@{
            ExitCode       = $ExitCode
            Output         = $Output
            ContextVerified = $ContextVerified
        }
    }
    finally {
        Unregister-ScheduledTask `
            -TaskName $TaskName `
            -Confirm:$false `
            -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $ResultPath, $LogPath -Force `
            -ErrorAction SilentlyContinue
    }
}

function Install-VlcFromDebianMirror {
    [CmdletBinding()]
    param()

    $Mirror = "https://cdimage.debian.org/mirror/videolan.org/vlc/last/win64/"
    $TemporaryRoot = Join-Path `
        ([IO.Path]::GetTempPath()) `
        ("larrybootstrap-vlc-" + [guid]::NewGuid().ToString("N"))

    New-Item -ItemType Directory -Path $TemporaryRoot | Out-Null
    try {
        Write-InfoLine "VLC fallback" "checking Debian's VideoLAN mirror"
        $Index = Invoke-WebRequest -Uri $Mirror -UseBasicParsing
        $AssetName = @(
            $Index.Links |
                ForEach-Object href |
                Where-Object { $_ -match '^vlc-[0-9.]+-win64\.msi$' }
        ) | Select-Object -First 1

        if (-not $AssetName) {
            $Match = [regex]::Match(
                $Index.Content,
                'href=["''](?<Asset>vlc-[0-9.]+-win64\.msi)["'']'
            )
            if ($Match.Success) { $AssetName = $Match.Groups["Asset"].Value }
        }

        if (-not $AssetName) {
            throw "No current win64 MSI was listed by the mirror."
        }

        $InstallerPath = Join-Path $TemporaryRoot $AssetName
        Write-InfoLine "VLC fallback" "downloading $AssetName"
        Invoke-WebRequest `
            -Uri ([uri]::new([uri]$Mirror, $AssetName).AbsoluteUri) `
            -OutFile $InstallerPath `
            -UseBasicParsing

        $Signature = Get-AuthenticodeSignature -FilePath $InstallerPath
        $Signer = [string]$Signature.SignerCertificate.Subject
        if ($Signature.Status -ne "Valid" -or $Signer -notmatch "VideoLAN") {
            throw "VLC MSI did not have a valid VideoLAN signature."
        }

        $Process = Start-Process `
            -FilePath "$env:SystemRoot\System32\msiexec.exe" `
            -ArgumentList @("/i", ('"{0}"' -f $InstallerPath), "/quiet", "/norestart") `
            -Wait `
            -PassThru
        if ($Process.ExitCode -notin @(0, 3010)) {
            throw "VLC MSI failed with exit code $($Process.ExitCode)."
        }

        Write-OK "VLC fallback" "installed from Debian's VideoLAN mirror"
        return $true
    }
    catch {
        Write-Warn "VLC fallback" $_.Exception.Message
        return $false
    }
    finally {
        Remove-Item `
            -LiteralPath $TemporaryRoot `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

function Install-WinGetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$Package,
        [switch]$DryRun
    )

    $script:LastWinGetInstallRecoverable = $false

    if (Test-WinGetPackageInstalled $Package.Id) {
        Write-OK $Package.DisplayName "already installed"
        return $true
    }

    if ($DryRun) {
        Write-InfoLine $Package.DisplayName `
            "would install in $($Package.Context) context ($($Package.Id))"
        return $true
    }

    Write-InfoLine $Package.DisplayName `
        "installing in $($Package.Context) context..."

    $Arguments = @(
        "install", "--id", $Package.Id, "--exact",
        "--accept-package-agreements", "--accept-source-agreements",
        "--disable-interactivity"
    )
    $MaximumAttempts = if ($Package.Required) { 3 } else { 1 }
    $ExitCode = 1
    $Output = @()

    for ($Attempt = 1; $Attempt -le $MaximumAttempts; $Attempt++) {
        if ($Package.Context -eq "user") {
            Write-InfoLine $Package.DisplayName `
                "launching unelevated as $env:USERNAME"
            $Result = Invoke-WinGetPackageAsInteractiveUser -PackageId $Package.Id
            $ExitCode = $Result.ExitCode
            $Output = @($Result.Output)
            if (-not $Result.ContextVerified) {
                $ExitCode = 740
                $Output += "User-token helper did not verify Elevated=False."
            }
        }
        else {
            $Output = @(& winget @Arguments 2>&1)
            $ExitCode = $LASTEXITCODE
        }
        $Output | Out-Host

        if ($ExitCode -eq 0) { break }
        if ($Attempt -lt $MaximumAttempts) {
            $Delay = @(5, 15)[$Attempt - 1]
            Write-Warn $Package.DisplayName `
                "attempt $Attempt failed; retrying in $Delay seconds"
            Start-Sleep -Seconds $Delay
        }
    }

    if ($ExitCode -eq 0) {
        Write-OK $Package.DisplayName "installed"
        return $true
    }

    $FailureText = $Output -join " "
    $script:LastWinGetInstallRecoverable = $FailureText -match `
        "0x80072ee7|InternetOpenUrl\(\) failed|name resolution|network|download"

    if (
        $Package.Id -eq "VideoLAN.VLC" -and
        $script:LastWinGetInstallRecoverable -and
        (Install-VlcFromDebianMirror)
    ) {
        $script:LastWinGetInstallRecoverable = $false
        return $true
    }

    if ($script:LastWinGetInstallRecoverable) {
        Write-Warn $Package.DisplayName `
            "download failed; rerun LarryBootstrap when the source is reachable"
    }
    elseif ($Package.Required) {
        Write-Fail $Package.DisplayName "installation failed"
    }
    else {
        Write-Warn $Package.DisplayName "optional package failed"
    }

    return $false
}

