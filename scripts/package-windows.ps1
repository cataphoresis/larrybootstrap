param(
    [ValidatePattern('^\d+\.\d+\.\d+([.-][0-9A-Za-z.-]+)?$')]
    [string]$Version = '0.1.0',

    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$packageName = "LarryBootstrap-Windows-v$Version"
$stagingRoot = Join-Path $OutputDirectory '.staging'
$packageRoot = Join-Path $stagingRoot $packageName
$archivePath = Join-Path $OutputDirectory "$packageName.zip"
$checksumPath = "$archivePath.sha256"

if (-not (Get-Command pwsh.exe -ErrorAction SilentlyContinue)) {
    throw 'PowerShell 7 (pwsh.exe) is required to build and run this package.'
}

if (Test-Path -LiteralPath $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

$files = @(
    'launcher.ps1'
    'bootstrap.ps1'
    'README.md'
    'packaging/windows/README-WINDOWS.md'
    'packaging/windows/RELEASE_NOTES.md'
    'common/profiles/standard.json'
)

foreach ($relativePath in $files) {
    $source = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required package file is missing: $relativePath"
    }

    $destinationRelativePath = switch ($relativePath) {
        'packaging/windows/README-WINDOWS.md' { 'README-WINDOWS.md' }
        'packaging/windows/RELEASE_NOTES.md' { 'RELEASE_NOTES.md' }
        default { $relativePath }
    }
    $destination = Join-Path $packageRoot $destinationRelativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
}

$windowsSource = Join-Path $repositoryRoot 'platforms/windows'
$windowsDestination = Join-Path $packageRoot 'platforms/windows'
if (-not (Test-Path -LiteralPath $windowsSource -PathType Container)) {
    throw 'Required Windows platform directory is missing.'
}
Copy-Item -LiteralPath $windowsSource -Destination $windowsDestination -Recurse -Force

# Runtime output and local-machine state do not belong in a release archive.
Get-ChildItem -LiteralPath $packageRoot -Directory -Recurse -Force |
    Where-Object Name -in @('reports', 'logs', 'backups') |
    ForEach-Object {
        Get-ChildItem -LiteralPath $_.FullName -File -Force |
            Where-Object Name -ne '.gitkeep' |
            Remove-Item -Force
    }

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
if (Test-Path -LiteralPath $checksumPath) {
    Remove-Item -LiteralPath $checksumPath -Force
}

Compress-Archive -LiteralPath $packageRoot -DestinationPath $archivePath -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$hash  $([IO.Path]::GetFileName($archivePath))" -Encoding ascii

Remove-Item -LiteralPath $stagingRoot -Recurse -Force

Write-Host "Created $archivePath"
Write-Host "Created $checksumPath"

