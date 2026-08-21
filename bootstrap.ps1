param(
    [ValidateSet("standard")]
    [string]$Profile = "standard",

    [switch]$VerifyOnly,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw "bootstrap.ps1 is the Windows launcher. Use ./bootstrap.sh on macOS or Linux."
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$StageZero = Join-Path $Root "platforms\windows\stage0.ps1"

if (-not (Test-Path -LiteralPath $StageZero -PathType Leaf)) {
    throw "Windows Stage 0 bootstrap not found: $StageZero"
}

& $StageZero `
    -Profile $Profile `
    -VerifyOnly:$VerifyOnly `
    -DryRun:$DryRun
exit $LASTEXITCODE
