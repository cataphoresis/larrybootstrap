param(
    [ValidateSet("standard", "homelab", "developer")]
    [string]$Profile = "standard",

    [switch]$VerifyOnly
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

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

    & $VerifyModule
    exit $LASTEXITCODE
}

Write-Host "Bootstrap repository is initialized."
Write-Host "No system changes have been made yet."
