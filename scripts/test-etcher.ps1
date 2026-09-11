# Offline resolver checks. Run with PowerShell 7 on any OS.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Tokens = $null
$Errors = $null
$Ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $Root 'platforms/windows/modules/30-direct-installs.ps1'), [ref]$Tokens, [ref]$Errors)
if ($Errors) { throw $Errors[0] }
foreach ($Name in @('Test-AllowedDownloadHost', 'Resolve-DirectDownloadUri')) {
    $Function = $Ast.Find({ param($Node) $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Node.Name -eq $Name }, $true)
    . ([scriptblock]::Create($Function.Extent.Text))
}
$Package = (Get-Content (Join-Path $Root 'platforms/windows/profiles/direct-installs-standard.json') -Raw | ConvertFrom-Json).packages |
    Where-Object { $_.PSObject.Properties.Name -contains 'githubRepository' -and $_.githubRepository -eq 'balena-io/etcher' }
$script:TestCase = 'normal'
function Invoke-RestMethod {
    param($Uri)
    $Asset = [pscustomobject]@{ name = 'balenaEtcher-9.8.7.Setup.exe'; browser_download_url = 'https://github.com/balena-io/etcher/releases/download/v9.8.7/balenaEtcher-9.8.7.Setup.exe'; digest = ('sha256:' + ('a' * 64)) }
    if ($script:TestCase -eq 'ambiguous') { return @{ assets = @($Asset, $Asset) } }
    if ($script:TestCase -eq 'missing') { return @{ assets = @() } }
    return @{ assets = @($Asset) }
}
function Invoke-WebRequest {
    param($Uri, $Method, $MaximumRedirection, [switch]$UseBasicParsing)
    $Final = if ($script:TestCase -eq 'redirect') { 'https://example.org/untrusted.exe' } else { 'https://release-assets.githubusercontent.com/asset.exe' }
    return @{ BaseResponse = @{ RequestMessage = @{ RequestUri = [uri]$Final } } }
}
$Resolved = Resolve-DirectDownloadUri $Package
if ($Resolved.DnsSafeHost -ne 'release-assets.githubusercontent.com') { throw 'Incorrect release resolution' }
if ($script:ResolvedAssetDigest -ne ('sha256:' + ('a' * 64))) { throw 'Digest not retained' }
foreach ($Case in @('ambiguous', 'missing', 'redirect')) {
    $script:TestCase = $Case
    $Rejected = $false
    try { Resolve-DirectDownloadUri $Package | Out-Null } catch { $Rejected = $true }
    if (-not $Rejected) { throw "Failed to reject $Case" }
}
Write-Output 'Etcher resolution, ambiguity, missing asset, and untrusted redirect: PASS'
