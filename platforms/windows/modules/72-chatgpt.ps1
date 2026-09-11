param([switch]$DryRun, [switch]$VerifyOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\Common.ps1"
$Id = '9PLM9XGG6VKS' # Current official desktop app, not ChatGPT Classic.
Write-Section 'Official ChatGPT desktop'
if (Test-WinGetPackageInstalled -Id $Id) {
    Write-OK 'ChatGPT' 'installed'
    exit 0
}
if ($VerifyOnly) { Write-Fail 'ChatGPT' 'not installed'; exit 1 }
if ($DryRun) {
    Write-InfoLine 'ChatGPT' "would install $Id from Microsoft Store as interactive user"
    exit 0
}
$Result = Invoke-WinGetPackageAsInteractiveUser -PackageId $Id -Source msstore
if ($Result.ExitCode -ne 0 -or -not $Result.ContextVerified) {
    Write-Fail 'ChatGPT' "Store installation failed ($($Result.ExitCode))"
    Write-InfoLine 'Manual download' 'https://get.microsoft.com/installer/download/9PLM9XGG6VKS'
    exit 1
}
if (-not (Test-WinGetPackageInstalled -Id $Id)) {
    Write-Fail 'ChatGPT' 'Store installation returned success but app is not detected'
    exit 1
}
Write-OK 'ChatGPT' 'installed; open the app to sign in'
