param(
    [ValidateSet("standard")]
    [string]$Profile = "standard",

    [switch]$VerifyOnly,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$PwshPath = (Get-Command pwsh.exe -ErrorAction Stop).Source
. "$Root\modules\lib\Common.ps1"

# Each module runs in a fresh PowerShell process. Refresh PATH at entry so a
# standalone verification sees tools installed by an earlier apply process.
$MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$ExpectedToolPaths = @(
    (Join-Path $env:ProgramFiles "nodejs"),
    (Join-Path $env:APPDATA "npm"),
    (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin")
)
$env:Path = @(
    @($MachinePath, $UserPath) -join ";" -split ";"
    $ExpectedToolPaths | Where-Object { Test-Path -LiteralPath $_ }
) | Where-Object { $_ } | Select-Object -Unique | Join-String -Separator ";"

$ArtifactRetentionCount = 3
$DryRunStageFailures = 0
$DeferredStatePath = if ($DryRun -or $VerifyOnly) {
    $null
}
else {
    Join-Path `
        ([IO.Path]::GetTempPath()) `
        ("larrybootstrap-deferred-" + [guid]::NewGuid().ToString("N") + ".json")
}

Write-Host ""
Write-LarryBorder
Write-Host " Windows Bootstrap"
Write-LarryBorder
Write-Host "Profile:    $Profile"
Write-Host "User:       $env:USERNAME"
Write-Host "Computer:   $env:COMPUTERNAME"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "Started:    $(Get-Date)"
Write-Host "Mode:       $(if ($DryRun) { 'DRY RUN - no persistent changes' } else { 'APPLY' })"
Write-Host ""

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "Run this bootstrap from PowerShell 7 (pwsh), not Windows PowerShell 5.1."
}

if ($VerifyOnly) {
    $VerifyModule = Join-Path $Root "modules\90-verify.ps1"

    if (-not (Test-Path $VerifyModule)) {
        throw "Verification module does not exist yet."
    }

    try {
        $VerifyArguments = @("-Profile", $Profile)
        if ($DryRun) { $VerifyArguments += "-DryRun" }
        & $PwshPath -NoLogo -NoProfile -File $VerifyModule @VerifyArguments
        $VerifyExitCode = $LASTEXITCODE
    }
    finally {
        Invoke-BootstrapArtifactRetention `
            -RootDirectory $Root `
            -KeepPerModule $ArtifactRetentionCount `
            -DryRun:$DryRun
    }

    exit $VerifyExitCode
}

$WinGetArguments = @("-Profile", $Profile)
$VerificationArguments = @("-Profile", $Profile)
if ($DeferredStatePath) {
    $WinGetArguments += @("-DeferredStatePath", $DeferredStatePath)
    $VerificationArguments += @("-DeferredStatePath", $DeferredStatePath)
}

$Pipeline = @(
    [pscustomobject]@{ Name = "Preflight";        File = "00-preflight.ps1";        Arguments = @() },
    [pscustomobject]@{ Name = "Inventory";        File = "01-inventory.ps1";        Arguments = @() },
    [pscustomobject]@{ Name = "WinGet packages";  File = "10-winget.ps1";          Arguments = $WinGetArguments },
    [pscustomobject]@{ Name = "Retired cleanup";  File = "12-cleanup.ps1";         Arguments = @() },
    [pscustomobject]@{ Name = "Filesystem compat"; File = "15-filesystem-compat.ps1"; Arguments = @() },
    [pscustomobject]@{ Name = "Windows settings"; File = "20-settings.ps1";        Arguments = @() },
    [pscustomobject]@{ Name = "Direct installs";  File = "30-direct-installs.ps1"; Arguments = @("-Profile", $Profile) },
    [pscustomobject]@{ Name = "Larry PowerShell"; File = "40-powershell.ps1";      Arguments = @() },
    [pscustomobject]@{ Name = "Browser setup";     File = "50-browser.ps1";         Arguments = @() },
    [pscustomobject]@{ Name = "PowerToys setup";   File = "60-workspaces.ps1";      Arguments = @() },
    [pscustomobject]@{ Name = "Developer tooling"; File = "70-developer-tools.ps1"; Arguments = @() },
    [pscustomobject]@{ Name = "Verification";     File = "90-verify.ps1";          Arguments = $VerificationArguments }
)

try {
    foreach ($Stage in $Pipeline) {
        $ModulePath = Join-Path $Root "modules\$($Stage.File)"

        if (-not (Test-Path -LiteralPath $ModulePath -PathType Leaf)) {
            throw "Bootstrap module not found: $ModulePath"
        }

        Write-Host ""
        Write-LarryBorder
        Write-Host (" {0}" -f $Stage.Name) -ForegroundColor Cyan
        Write-LarryBorder

        $StageArguments = @($Stage.Arguments)
        if ($DryRun) { $StageArguments += "-DryRun" }
        & $PwshPath -NoLogo -NoProfile -File $ModulePath @StageArguments
        $ModuleExitCode = $LASTEXITCODE

        if ($ModuleExitCode -ne 0) {
            if ($DryRun) {
                $DryRunStageFailures++
                Write-Warn `
                    -Label $Stage.Name `
                    -Message "exit code $ModuleExitCode; continuing dry-run inspection"
                continue
            }

            throw "$($Stage.Name) failed with exit code $ModuleExitCode."
        }

        if ($Stage.File -eq "10-winget.ps1" -and -not $DryRun) {
            $MachinePath = [Environment]::GetEnvironmentVariable(
                "Path",
                "Machine"
            )
            $UserPath = [Environment]::GetEnvironmentVariable(
                "Path",
                "User"
            )
            $env:Path = "$MachinePath;$UserPath"
        }
    }
}
finally {
    if ($DeferredStatePath) {
        Remove-Item `
            -LiteralPath $DeferredStatePath `
            -Force `
            -ErrorAction SilentlyContinue
    }

    Invoke-BootstrapArtifactRetention `
        -RootDirectory $Root `
        -KeepPerModule $ArtifactRetentionCount `
        -DryRun:$DryRun
}

Write-Host ""
if ($DryRun) {
    Write-Host "Windows bootstrap dry run completed; no persistent changes were made." -ForegroundColor Green
    Write-Host "Stages reporting failures: $DryRunStageFailures"
    exit $(if ($DryRunStageFailures -gt 0) { 1 } else { 0 })
}

Write-Host "Windows bootstrap completed successfully." -ForegroundColor Green
exit 0
