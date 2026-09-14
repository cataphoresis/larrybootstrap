# Offline regression checks: runtime detection must agree in apply and verify.
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
foreach ($entry in @(
    @{ File = '30-direct-installs.ps1'; Function = 'Find-InstalledApplication' },
    @{ File = '90-verify.ps1'; Function = 'Find-DirectApplication' }
)) {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $RepositoryRoot "platforms/windows/modules/$($entry.File)"), [ref]$tokens, [ref]$errors)
    if ($errors) { throw $errors[0] }
    foreach ($name in @('Get-ExpandedDetectionPath', $entry.Function)) {
        $node = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true)
        if ($node) { . ([scriptblock]::Create($node.Extent.Text)) }
    }
}
$runtime = [pscustomobject]@{ detectionRegistry = 'HKLM:\TEST-ONLY'; detectionPaths = @($PSCommandPath) }
function Get-ItemProperty { param($LiteralPath, $ErrorAction) return $script:runtimeState }
foreach ($case in @(
    @{ Name = 'absent'; State = $null; Present = $false },
    @{ Name = 'uninstalled'; State = [pscustomobject]@{ Installed = 0; Version = 'v14.51.36247.00' }; Present = $false },
    @{ Name = 'wrong runtime generation'; State = [pscustomobject]@{ Installed = 1; Version = 'v13.0.0.0' }; Present = $false },
    @{ Name = 'installed x64 v14'; State = [pscustomobject]@{ Installed = 1; Version = 'v14.51.36247.00' }; Present = $true }
)) {
    $script:runtimeState = $case.State
    foreach ($check in @('Find-InstalledApplication', 'Find-DirectApplication')) {
        if ([bool](& $check $runtime) -ne $case.Present) { throw "${check}: $($case.Name)" }
    }
}
$filePackage = [pscustomobject]@{ detectionPaths = @($PSCommandPath) }
foreach ($check in @('Find-InstalledApplication', 'Find-DirectApplication')) {
    if ((& $check $filePackage) -ne $PSCommandPath) { throw "File detection regressed in $check" }
}
Write-Output 'Runtime absence, uninstall state, generation, installed state, and file detection: PASS'
