param(
    [ValidateSet("standard", "homelab", "developer")]
    [string]$Profile = "standard",

    [switch]$VerifyOnly
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$PwshPath = (Get-Command pwsh.exe -ErrorAction Stop).Source
. "$Root\modules\lib\Common.ps1"

$ArtifactRetentionCount = 3

Write-Host ""
Write-Host "============================================================"
Write-Host " Windows Bootstrap"
Write-Host "============================================================"
Write-Host "Profile:    $Profile"
Write-Host "User:       $env:USERNAME"
Write-Host "Computer:   $env:COMPUTERNAME"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "Started:    $(Get-Date)"
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
        & $PwshPath -NoLogo -NoProfile -File $VerifyModule -Profile $Profile
        $VerifyExitCode = $LASTEXITCODE
    }
    finally {
        Invoke-BootstrapArtifactRetention `
            -RootDirectory $Root `
            -KeepPerModule $ArtifactRetentionCount
    }

    exit $VerifyExitCode
}

$Pipeline = @(
    [pscustomobject]@{ Name = "Preflight";        File = "00-preflight.ps1";        Arguments = @() },
    [pscustomobject]@{ Name = "Inventory";        File = "01-inventory.ps1";        Arguments = @() },
    [pscustomobject]@{ Name = "WinGet packages";  File = "10-winget.ps1";          Arguments = @("-Profile", $Profile) },
    [pscustomobject]@{ Name = "Windows settings"; File = "20-settings.ps1";        Arguments = @() },
    [pscustomobject]@{ Name = "Direct installs";  File = "30-direct-installs.ps1"; Arguments = @("-Profile", $Profile) },
    [pscustomobject]@{ Name = "Larry PowerShell"; File = "40-powershell.ps1";      Arguments = @() },
    [pscustomobject]@{ Name = "Verification";     File = "90-verify.ps1";          Arguments = @("-Profile", $Profile) }
)

try {
    foreach ($Stage in $Pipeline) {
        $ModulePath = Join-Path $Root "modules\$($Stage.File)"

        if (-not (Test-Path -LiteralPath $ModulePath -PathType Leaf)) {
            throw "Bootstrap module not found: $ModulePath"
        }

        Write-Host ""
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host (" {0}" -f $Stage.Name) -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan

        $StageArguments = @($Stage.Arguments)
        & $PwshPath -NoLogo -NoProfile -File $ModulePath @StageArguments
        $ModuleExitCode = $LASTEXITCODE

        if ($ModuleExitCode -ne 0) {
            throw "$($Stage.Name) failed with exit code $ModuleExitCode."
        }
    }
}
finally {
    Invoke-BootstrapArtifactRetention `
        -RootDirectory $Root `
        -KeepPerModule $ArtifactRetentionCount
}

Write-Host ""
Write-Host "Windows bootstrap completed successfully." -ForegroundColor Green
exit 0
