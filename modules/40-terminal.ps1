param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$SchemaPath = Join-Path $Root "schema\terminal.json"
$Schema = Get-Content $SchemaPath -Raw | ConvertFrom-Json

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BackupRoot = Join-Path $Root "backups\terminal-$Timestamp"
$Report = New-TimestampedReport `
    -RootDirectory $Root `
    -Prefix "terminal"

New-Item -ItemType Directory -Force $BackupRoot | Out-Null

$Failures = 0
$Warnings = 0
$Changes = 0

function Add-ReportLine {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

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

"Windows Terminal Configuration" | Set-Content -Encoding UTF8 $Report
"==============================" | Add-Content $Report
"Run date: $(Get-Date)" | Add-Content $Report
"" | Add-Content $Report

Write-Section "Windows Terminal Configuration"

$PwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"

if (-not (Test-Path -LiteralPath $PwshPath)) {
    Record-Fail "PowerShell 7" "pwsh.exe not found at $PwshPath"
}

if (-not (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
    Record-Fail "Windows Terminal" "wt.exe not found"
}

if ($Failures -gt 0) {
    exit 1
}

Record-OK "PowerShell 7" "available"
Record-OK "Windows Terminal" "available"

Write-Section "Terminal Fragment"

$FragmentDirectory = Join-Path `
    $env:LOCALAPPDATA `
    "Microsoft\Windows Terminal\Fragments\LarryLauncher"

$FragmentPath = Join-Path $FragmentDirectory "larry-powershell.json"

New-Item -ItemType Directory -Force $FragmentDirectory | Out-Null

$Fragment = [ordered]@{
    profiles = @(
        [ordered]@{
            name              = $Schema.profileName
            guid              = $Schema.profileGuid
            commandline       = $Schema.commandline
            startingDirectory = $Schema.startingDirectory
            colorScheme       = $Schema.colorScheme
            padding           = $Schema.padding
            historySize       = [int]$Schema.historySize
            font              = [ordered]@{
                face = $Schema.fontFace
                size = [int]$Schema.fontSize
            }
        }
    )

    schemes = @(
        [ordered]@{
            name        = "Larry Dark"
            background  = "#101216"
            foreground  = "#E6E6E6"
            cursorColor = "#F3C623"
            selectionBackground = "#3A414D"

            black       = "#101216"
            red         = "#E06C75"
            green       = "#98C379"
            yellow      = "#E5C07B"
            blue        = "#61AFEF"
            purple      = "#C678DD"
            cyan        = "#56B6C2"
            white       = "#ABB2BF"

            brightBlack  = "#5C6370"
            brightRed    = "#E06C75"
            brightGreen  = "#98C379"
            brightYellow = "#E5C07B"
            brightBlue   = "#61AFEF"
            brightPurple = "#C678DD"
            brightCyan   = "#56B6C2"
            brightWhite  = "#FFFFFF"
        }
    )
}

$Fragment |
    ConvertTo-Json -Depth 10 |
    Set-Content -Encoding UTF8 $FragmentPath

$Changes++
Record-OK "Larry profile fragment" $FragmentPath

Write-Section "Default Profile"

$SettingsCandidates = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)

$SettingsPath = $SettingsCandidates |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if (-not $SettingsPath) {
    Record-Warn "Terminal settings" `
        "settings.json not found; open Windows Terminal once, then rerun"
}
else {
    Copy-Item `
        $SettingsPath `
        (Join-Path $BackupRoot "settings.json") `
        -Force

    Record-OK "Settings backup" `
        (Join-Path $BackupRoot "settings.json")

    $SettingsText = Get-Content $SettingsPath -Raw
    $Guid = $Schema.profileGuid

    if ($SettingsText -match '"defaultProfile"\s*:\s*"[^"]*"') {
        $UpdatedText = $SettingsText -replace `
            '"defaultProfile"\s*:\s*"[^"]*"', `
            "`"defaultProfile`": `"$Guid`""
    }
    else {
        $UpdatedText = $SettingsText -replace `
            '^\s*\{', `
            "{`r`n    `"defaultProfile`": `"$Guid`","
    }

    if ($UpdatedText -ne $SettingsText) {
        Set-Content `
            -Path $SettingsPath `
            -Value $UpdatedText `
            -Encoding UTF8

        $Changes++
        Record-OK "Default profile" $Schema.profileName
    }
    else {
        Record-OK "Default profile" "already configured"
    }
}

Write-Section "Launcher Shortcut"

$ShortcutDirectory = Join-Path `
    $env:APPDATA `
    "Microsoft\Windows\Start Menu\Programs"

$ShortcutPath = Join-Path `
    $ShortcutDirectory `
    "Larry PowerShell.lnk"

$Shell = New-Object -ComObject WScript.Shell
$Shortcut = $Shell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = (Get-Command wt.exe).Source
$Shortcut.Arguments = "-p `"$($Schema.profileName)`""
$Shortcut.WorkingDirectory = $HOME
$Shortcut.Description = "Open Larry PowerShell in Windows Terminal"
$Shortcut.Save()

$Changes++
Record-OK "Start-menu shortcut" $ShortcutPath

Write-Section "Terminal Result"

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
Add-ReportLine "Report: $Report"
Add-ReportLine "Backup: $BackupRoot"

if ($Failures -gt 0) {
    exit 1
}

exit 0

