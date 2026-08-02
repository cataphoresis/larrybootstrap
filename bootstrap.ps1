param(
    [ValidateSet("standard", "homelab", "developer")]
    [string]$Profile = "standard",

    [switch]$VerifyOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $IsWindows) {
    throw "bootstrap.ps1 is the Windows launcher. Use ./bootstrap.sh on macOS or Linux."
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$PlatformBootstrap = Join-Path $Root "platforms\windows\bootstrap.ps1"

if (-not (Test-Path -LiteralPath $PlatformBootstrap -PathType Leaf)) {
    throw "Windows platform bootstrap not found: $PlatformBootstrap"
}

$Arguments = @("-Profile", $Profile)

if ($VerifyOnly) {
    $Arguments += "-VerifyOnly"
}

$Pwsh = Get-Command pwsh.exe -ErrorAction Stop
& $Pwsh.Source -NoLogo -NoProfile -File $PlatformBootstrap @Arguments
exit $LASTEXITCODE
