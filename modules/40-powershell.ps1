param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$SchemaPath = Join-Path $Root "schema\powershell.json"
$Schema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BackupRoot = Join-Path $Root "backups\powershell-$Timestamp"
$Report = New-TimestampedReport -RootDirectory $Root -Prefix "powershell"
$Failures = 0
$Warnings = 0
$Changes = 0

New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null

function Add-ReportLine {
    param([AllowEmptyString()][string]$Text)
    $Text | Add-Content -Encoding UTF8 $Report
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

"Windows PowerShell Configuration" | Set-Content -Encoding UTF8 $Report
"================================" | Add-Content $Report
"Run date: $(Get-Date)" | Add-Content $Report
"Schema: $SchemaPath" | Add-Content $Report
"" | Add-Content $Report

Write-Section "Larry PowerShell Configuration"

$PwshCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue

if (-not $PwshCommand) {
    Record-Fail "PowerShell 7" "pwsh.exe was not found"
    exit 1
}

$PwshPath = $PwshCommand.Source
$ProjectsPath = Join-Path $HOME "Projects"
Record-OK "PowerShell 7" $PwshPath

New-Item -ItemType Directory -Force -Path $ProjectsPath | Out-Null
Record-OK "Projects directory" $ProjectsPath

Write-Section "PowerShell Profile"

$ProfilePath = & $PwshPath -NoLogo -NoProfile -Command '$PROFILE.CurrentUserAllHosts'

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ProfilePath)) {
    Record-Fail "Profile path" "PowerShell 7 did not return a profile path"
    exit 1
}

$ProfilePath = [string]$ProfilePath
$ProfileDirectory = Split-Path -Parent $ProfilePath
New-Item -ItemType Directory -Force -Path $ProfileDirectory | Out-Null

$ExistingProfile = if (Test-Path -LiteralPath $ProfilePath) {
    Copy-Item -LiteralPath $ProfilePath -Destination (Join-Path $BackupRoot "Microsoft.PowerShell_profile.ps1") -Force
    Record-OK "Profile backup" $BackupRoot
    Get-Content -LiteralPath $ProfilePath -Raw
}
else {
    ""
}

$BeginMarker = "# BEGIN LARRY-BOOTSTRAP"
$EndMarker = "# END LARRY-BOOTSTRAP"
$Banner = if ($Schema.showBanner) {
@'
Write-Host ""
Write-Host "Larry Workstation" -ForegroundColor Cyan
Write-Host ("PowerShell {0}  |  {1}" -f $PSVersionTable.PSVersion, $env:COMPUTERNAME)
Write-Host ("Projects: {0}" -f $LarryProjects)
Write-Host ""
'@
}
else {
    ""
}

$ManagedBlock = @"
$BeginMarker
`$LarryProjects = Join-Path `$HOME "Projects"

if (Test-Path -LiteralPath `$LarryProjects) {
    Set-Location -LiteralPath `$LarryProjects
}

if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode $($Schema.editMode) -HistorySaveStyle $($Schema.historySaveStyle) -MaximumHistoryCount $($Schema.historySize)

    try {
        Set-PSReadLineOption -PredictionSource $($Schema.predictionSource)
    }
    catch {
        # Prediction support varies by host and PSReadLine version.
    }
}

`$env:EDITOR = "$($Schema.editor)"
`$env:VISUAL = "$($Schema.visualEditor)"

function cproj { Set-Location -LiteralPath `$LarryProjects }
function ll { Get-ChildItem @args }
function la { Get-ChildItem -Force @args }

$Banner
$EndMarker
"@

$MarkerPattern = "(?s)" + [regex]::Escape($BeginMarker) + ".*?" + [regex]::Escape($EndMarker)
$UpdatedProfile = if ($ExistingProfile -match $MarkerPattern) {
    [regex]::Replace($ExistingProfile, $MarkerPattern, $ManagedBlock)
}
elseif ([string]::IsNullOrWhiteSpace($ExistingProfile)) {
    "$ManagedBlock`r`n"
}
else {
    $ExistingProfile.TrimEnd() + "`r`n`r`n$ManagedBlock`r`n"
}

if ($UpdatedProfile -ne $ExistingProfile) {
    Set-Content -LiteralPath $ProfilePath -Value $UpdatedProfile -Encoding UTF8
    $Changes++
    Record-OK "Managed profile" "updated $ProfilePath"
}
else {
    Record-OK "Managed profile" "already configured"
}

Write-Section "Editor Environment"

foreach ($Name in @("EDITOR", "VISUAL")) {
    $Value = if ($Name -eq "EDITOR") { [string]$Schema.editor } else { [string]$Schema.visualEditor }
    $CurrentValue = [Environment]::GetEnvironmentVariable($Name, "User")

    if ($CurrentValue -ne $Value) {
        [Environment]::SetEnvironmentVariable($Name, $Value, "User")
        $Changes++
        Record-OK $Name "set to $Value"
    }
    else {
        Record-OK $Name "already set to $Value"
    }
}

Write-Section "Larry PowerShell Shortcut"

$ShortcutDirectory = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
$ShortcutPath = Join-Path $ShortcutDirectory "$($Schema.name).lnk"
New-Item -ItemType Directory -Force -Path $ShortcutDirectory | Out-Null

$Shell = New-Object -ComObject WScript.Shell
$Shortcut = $Shell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $PwshPath
$Shortcut.Arguments = "-NoLogo"
$Shortcut.WorkingDirectory = $ProjectsPath
$Shortcut.Description = "Open $($Schema.name)"
$Shortcut.IconLocation = "$PwshPath,0"
$Shortcut.Save()
$Changes++
Record-OK "Start-menu shortcut" $ShortcutPath

Write-Section "Profile Validation"

$ValidationOutput = & $PwshPath -NoLogo -NoProfile -Command "& { . '$($ProfilePath.Replace("'", "''"))'; 'PROFILE_OK' }" 2>&1

if ($LASTEXITCODE -eq 0 -and $ValidationOutput -contains "PROFILE_OK") {
    Record-OK "Profile load test" "PASS"
}
else {
    Record-Fail "Profile load test" ($ValidationOutput -join " ")
}

Write-Section "PowerShell Result"
Write-InfoLine "Changes applied" $Changes.ToString()
Write-InfoLine "Warnings" $Warnings.ToString()
Write-InfoLine "Failures" $Failures.ToString()

if ($Failures -eq 0) {
    Write-OK "Overall status" "PASS"
}
else {
    Write-Fail "Overall status" "INCOMPLETE"
}

Write-InfoLine "Report" $Report
Write-InfoLine "Backup" $BackupRoot
Add-ReportLine ""
Add-ReportLine "Changes applied: $Changes"
Add-ReportLine "Warnings: $Warnings"
Add-ReportLine "Failures: $Failures"
Add-ReportLine "Overall status: $(if ($Failures -eq 0) { 'PASS' } else { 'INCOMPLETE' })"
Add-ReportLine "Report: $Report"
Add-ReportLine "Backup: $BackupRoot"

if ($Failures -gt 0) { exit 1 }
exit 0
