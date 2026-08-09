param([switch]$DryRun)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$SchemaPath = Join-Path $Root "schema\browser.json"
$Schema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BackupRoot = Join-Path $Root "backups\browser-$Timestamp"
$Report = New-TimestampedReport -RootDirectory $Root -Prefix "browser" -DryRun:$DryRun
$Failures = 0
$Warnings = 0
$Changes = 0

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

Add-ReportLine "Windows Browser Configuration"
Add-ReportLine "============================="
Add-ReportLine "Run date: $(Get-Date)"
Add-ReportLine "Schema: $SchemaPath"
Add-ReportLine ""

Write-Section "Browser Availability"

$FirefoxPath = Test-ApplicationPath -Paths @(
    "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
    "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
)

$ChromiumPath = Test-ApplicationPath -Paths @(
    "$env:ProgramFiles\Chromium\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Chromium\Application\chrome.exe",
    "$env:LOCALAPPDATA\Chromium\Application\chrome.exe"
)

if ($FirefoxPath) { Record-OK "Firefox" $FirefoxPath } else { Record-Fail "Firefox" "executable not found" }
if ($ChromiumPath) { Record-OK "Chromium" $ChromiumPath } else { Record-Warn "Chromium" "executable not found" }

if (-not $FirefoxPath) {
    exit 1
}

Write-Section "Firefox Enterprise Policy"

$FirefoxRoot = Split-Path -Parent $FirefoxPath
$DistributionPath = Join-Path $FirefoxRoot "distribution"
$PolicyPath = Join-Path $DistributionPath "policies.json"
if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $DistributionPath | Out-Null }

$Policy = if (Test-Path -LiteralPath $PolicyPath -PathType Leaf) {
    Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json -AsHashtable
}
else {
    @{}
}

if (-not $Policy.ContainsKey("policies")) {
    $Policy["policies"] = @{}
}

$InstallUrls = @($Schema.firefoxExtensions | ForEach-Object { [string]$_.installUrl })
$Policy["policies"]["Extensions"] = @{ Install = $InstallUrls }
$Policy["policies"]["DisableFirefoxStudies"] = $true
$Policy["policies"]["DontCheckDefaultBrowser"] = $false

$UpdatedPolicy = $Policy | ConvertTo-Json -Depth 20
$ExistingPolicy = if (Test-Path -LiteralPath $PolicyPath) {
    (Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json -AsHashtable) | ConvertTo-Json -Depth 20
}
else {
    ""
}

if ($UpdatedPolicy -ne $ExistingPolicy) {
    $Changes++
    if ($DryRun) {
        Record-OK "Firefox policy" "would update $PolicyPath"
    }
    else {
        New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
        if (Test-Path -LiteralPath $PolicyPath -PathType Leaf) {
            Copy-Item -LiteralPath $PolicyPath -Destination (Join-Path $BackupRoot "policies.json") -Force
            Record-OK "Policy backup" $BackupRoot
        }
        Set-Content -LiteralPath $PolicyPath -Value $UpdatedPolicy -Encoding UTF8
        Record-OK "Firefox policy" "updated $PolicyPath"
    }
}
else {
    Record-OK "Firefox policy" "already configured"
}

foreach ($Extension in $Schema.firefoxExtensions) {
    Record-OK $Extension.name "managed installation configured"
}

Write-Section "Default Browser"

$UserChoicePath = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice"
$DefaultProgId = Get-ItemPropertyValue -LiteralPath $UserChoicePath -Name "ProgId" -ErrorAction SilentlyContinue

if ($DefaultProgId -match '^FirefoxURL') {
    Record-OK "Primary browser" "Firefox is the HTTPS default"
}
else {
    Record-Warn "Primary browser" "select Firefox in Windows Default apps; current ProgId: $DefaultProgId"
}

Write-Section "Browser Result"
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
