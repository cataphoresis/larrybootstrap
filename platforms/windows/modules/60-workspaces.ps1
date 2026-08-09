param([switch]$DryRun)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$SchemaPath = Join-Path $Root "schema\workspaces.json"
$Schema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BackupRoot = Join-Path $Root "backups\workspaces-$Timestamp"
$Report = New-TimestampedReport -RootDirectory $Root -Prefix "workspaces" -DryRun:$DryRun
$PowerToysRoot = Join-Path $env:LOCALAPPDATA "Microsoft\PowerToys"
$SettingsPath = Join-Path $PowerToysRoot "settings.json"
$ExportPath = Join-Path $Root "profiles\powertoys"
$Failures = 0
$Warnings = 0
$Changes = 0

if (-not $DryRun -and -not (Test-Path -LiteralPath $ExportPath -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $ExportPath | Out-Null
}

function Add-ReportLine {
    param([AllowEmptyString()][string]$Text)
    if ($Report) { $Text | Add-Content -Encoding UTF8 $Report }
}

function Record-OK {
    param([string]$Label, [string]$Message)
    Write-OK $Label $Message
    Add-ReportLine ("[ OK ] {0,-28} {1}" -f $Label, $Message)
}

function Record-Warn {
    param([string]$Label, [string]$Message)
    $script:Warnings++
    Write-Warn $Label $Message
    Add-ReportLine ("[WARN] {0,-28} {1}" -f $Label, $Message)
}

function Record-Fail {
    param([string]$Label, [string]$Message)
    $script:Failures++
    Write-Fail $Label $Message
    Add-ReportLine ("[FAIL] {0,-28} {1}" -f $Label, $Message)
}

Add-ReportLine "Windows PowerToys Workspace Configuration"
Add-ReportLine "========================================="
Add-ReportLine "Run date: $(Get-Date)"
Add-ReportLine "Schema: $SchemaPath"
Add-ReportLine ""

Write-Section "PowerToys Configuration"

if (-not (Test-WinGetPackageInstalled -Id "Microsoft.PowerToys")) {
    Record-Fail "PowerToys" "WinGet package is not installed"
    exit 1
}

Record-OK "PowerToys" "installed"

if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
    Record-Fail "PowerToys settings" "not found: $SettingsPath; open PowerToys once and rerun"
    exit 1
}

$Settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json -AsHashtable

if (-not $Settings.ContainsKey("enabled")) {
    $Settings["enabled"] = @{}
}

foreach ($Module in $Schema.requiredModules) {
    $Name = [string]$Module

    if ($Settings["enabled"].ContainsKey($Name) -and $Settings["enabled"][$Name] -eq $true) {
        Record-OK $Name "already enabled"
    }
    else {
        $Settings["enabled"][$Name] = $true
        $Changes++
        Record-OK $Name $(if ($DryRun) { "would enable" } else { "enabled" })
    }
}

$UpdatedSettings = $Settings | ConvertTo-Json -Depth 20 -Compress
$ExistingSettings = (Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json -AsHashtable) | ConvertTo-Json -Depth 20 -Compress

if ($UpdatedSettings -ne $ExistingSettings -and -not $DryRun) {
    New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
    Copy-Item -LiteralPath $SettingsPath -Destination (Join-Path $BackupRoot "settings.json") -Force
    Record-OK "Settings backup" $BackupRoot
    Set-Content -LiteralPath $SettingsPath -Value $UpdatedSettings -Encoding UTF8
}

Write-Section "Workspace Definitions"
if (Test-Path -LiteralPath $ExportPath -PathType Container) {
    Record-OK "Export directory" $ExportPath
}
elseif ($DryRun) {
    Record-OK "Export directory" "would create $ExportPath"
}

foreach ($Layout in $Schema.layouts) {
    Record-Warn $Layout.name "capture pending: $($Layout.purpose)"
}

Write-Section "Workspace Result"
Write-InfoLine $(if ($DryRun) { "Changes planned" } else { "Changes applied" }) $Changes.ToString()
Write-InfoLine "Warnings" $Warnings.ToString()
Write-InfoLine "Failures" $Failures.ToString()

$Status = if ($Failures -eq 0) { "PASS" } else { "INCOMPLETE" }
if ($Failures -eq 0) { Write-OK "Overall status" $Status } else { Write-Fail "Overall status" $Status }

if ($Report) { Write-InfoLine "Report" $Report } else { Write-InfoLine "Report" "suppressed in dry-run mode" }
Write-InfoLine "Backup" $(if ($DryRun) { "suppressed in dry-run mode" } else { $BackupRoot })
Add-ReportLine ""
Add-ReportLine "Changes applied: $Changes"
Add-ReportLine "Warnings: $Warnings"
Add-ReportLine "Failures: $Failures"
Add-ReportLine "Overall status: $Status"
Add-ReportLine "Report: $Report"
Add-ReportLine "Backup: $BackupRoot"

if ($Failures -gt 0) { exit 1 }
exit 0
