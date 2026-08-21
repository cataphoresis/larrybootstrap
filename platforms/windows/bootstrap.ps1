param(
    [ValidateSet("standard", "homelab", "developer")]
    [string]$Profile = "standard",

    [switch]$VerifyOnly,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$PwshPath = (Get-Command pwsh.exe -ErrorAction Stop).Source
. "$Root\modules\lib\Common.ps1"

$ArtifactRetentionCount = 3
$DryRunStageFailures = 0

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

$Pipeline = @(
    [pscustomobject]@{ Name = "Preflight";        File = "00-preflight.ps1";        Arguments = @() },
    [pscustomobject]@{ Name = "Inventory";        File = "01-inventory.ps1";        Arguments = @() },
    [pscustomobject]@{ Name = "WinGet packages";  File = "10-winget.ps1";          Arguments = @("-Profile", $Profile) },
    [pscustomobject]@{ Name = "Retired cleanup";  File = "12-cleanup.ps1";         Arguments = @() },
    [pscustomobject]@{ Name = "Filesystem compat"; File = "15-filesystem-compat.ps1"; Arguments = @() },
    [pscustomobject]@{ Name = "Windows settings"; File = "20-settings.ps1";        Arguments = @() },
    [pscustomobject]@{ Name = "Direct installs";  File = "30-direct-installs.ps1"; Arguments = @("-Profile", $Profile) },
    [pscustomobject]@{ Name = "OpenAI Codex";     File = "35-codex.ps1";          Arguments = @() },
    [pscustomobject]@{ Name = "Larry PowerShell"; File = "40-powershell.ps1";      Arguments = @() },
    [pscustomobject]@{ Name = "Browser setup";     File = "50-browser.ps1";         Arguments = @() },
    [pscustomobject]@{ Name = "PowerToys setup";   File = "60-workspaces.ps1";      Arguments = @() },
    [pscustomobject]@{ Name = "Verification";     File = "90-verify.ps1";          Arguments = @("-Profile", $Profile) }
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
