param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BackupRoot = Join-Path $Root "backups\settings-$Timestamp"
$Report = New-TimestampedReport `
    -RootDirectory $Root `
    -Prefix "settings"

New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null

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
    param(
        [string]$Label,
        [string]$Message
    )

    Write-OK $Label $Message
    Add-ReportLine ("[ OK ] {0,-28} {1}" -f $Label, $Message)
}

function Record-Warn {
    param(
        [string]$Label,
        [string]$Message
    )

    $script:Warnings++
    Write-Warn $Label $Message
    Add-ReportLine ("[WARN] {0,-28} {1}" -f $Label, $Message)
}

function Record-Fail {
    param(
        [string]$Label,
        [string]$Message
    )

    $script:Failures++
    Write-Fail $Label $Message
    Add-ReportLine ("[FAIL] {0,-28} {1}" -f $Label, $Message)
}

function Set-RegistrySetting {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [object]$Value,

        [ValidateSet("String", "ExpandString", "Binary", "DWord", "MultiString", "QWord")]
        [string]$Type = "DWord",

        [Parameter(Mandatory)]
        [string]$Label
    )

    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        $Existing = Get-ItemProperty `
            -LiteralPath $Path `
            -Name $Name `
            -ErrorAction SilentlyContinue

        $CurrentValue = $null

        if ($null -ne $Existing) {
            $CurrentValue = $Existing.$Name
        }

        if ($CurrentValue -eq $Value) {
            Record-OK $Label "already configured"
            return
        }

        New-ItemProperty `
            -LiteralPath $Path `
            -Name $Name `
            -Value $Value `
            -PropertyType $Type `
            -Force | Out-Null

        $script:Changes++
        Record-OK $Label "applied"
    }
    catch {
        Record-Fail $Label $_.Exception.Message
    }
}

"Windows Bootstrap Settings" | Set-Content -Encoding UTF8 $Report
"==========================" | Add-Content $Report
"Run date: $(Get-Date)" | Add-Content $Report
"Computer: $env:COMPUTERNAME" | Add-Content $Report
"User: $env:USERNAME" | Add-Content $Report
"Backup: $BackupRoot" | Add-Content $Report
"" | Add-Content $Report

Write-Section "Windows Settings Configuration"

Write-InfoLine "Backup directory" $BackupRoot
Write-InfoLine "Windows build" (
    (Get-CimInstance Win32_OperatingSystem).BuildNumber
)

Write-Section "Backing Up Registry Settings"

$RegistryBackups = @(
    @{
        Key  = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer"
        File = "explorer.reg"
    },
    @{
        Key  = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        File = "explorer-advanced.reg"
    },
    @{
        Key  = "HKCU\Control Panel\Desktop"
        File = "desktop.reg"
    },
    @{
        Key  = "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        File = "personalize.reg"
    },
    @{
        Key  = "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem"
        File = "filesystem.reg"
    }
)

foreach ($Backup in $RegistryBackups) {
    $Destination = Join-Path $BackupRoot $Backup.File

    & reg.exe export `
        $Backup.Key `
        $Destination `
        /y 2>$null | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Record-OK $Backup.File "saved"
    }
    else {
        Record-Warn $Backup.File "key absent or export unavailable"
    }
}

Write-Section "File Explorer"

$ExplorerAdvanced = `
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

$Explorer = `
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"

Set-RegistrySetting `
    -Path $ExplorerAdvanced `
    -Name "HideFileExt" `
    -Value 0 `
    -Type DWord `
    -Label "Show file extensions"

Set-RegistrySetting `
    -Path $ExplorerAdvanced `
    -Name "Hidden" `
    -Value 1 `
    -Type DWord `
    -Label "Show hidden files"

Set-RegistrySetting `
    -Path $ExplorerAdvanced `
    -Name "ShowSuperHidden" `
    -Value 0 `
    -Type DWord `
    -Label "Protected system files"

Set-RegistrySetting `
    -Path $ExplorerAdvanced `
    -Name "LaunchTo" `
    -Value 1 `
    -Type DWord `
    -Label "Explorer opens to This PC"

Set-RegistrySetting `
    -Path $Explorer `
    -Name "ShowRecent" `
    -Value 0 `
    -Type DWord `
    -Label "Recent files in Explorer"

Set-RegistrySetting `
    -Path $Explorer `
    -Name "ShowFrequent" `
    -Value 0 `
    -Type DWord `
    -Label "Frequent folders"

Set-RegistrySetting `
    -Path $ExplorerAdvanced `
    -Name "SeparateProcess" `
    -Value 0 `
    -Type DWord `
    -Label "Separate Explorer processes"

Write-Section "Taskbar and Search"

Set-RegistrySetting `
    -Path $ExplorerAdvanced `
    -Name "TaskbarSmallIcons" `
    -Value 1 `
    -Type DWord `
    -Label "Small taskbar icons"

Set-RegistrySetting `
    -Path `
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
    -Name "SearchboxTaskbarMode" `
    -Value 1 `
    -Type DWord `
    -Label "Compact taskbar search"

Set-RegistrySetting `
    -Path $ExplorerAdvanced `
    -Name "ShowTaskViewButton" `
    -Value 1 `
    -Type DWord `
    -Label "Task View button"

Write-Section "Responsiveness"

$DesktopPath = "HKCU:\Control Panel\Desktop"
$WindowMetricsPath = "HKCU:\Control Panel\Desktop\WindowMetrics"

Set-RegistrySetting `
    -Path $DesktopPath `
    -Name "MenuShowDelay" `
    -Value "100" `
    -Type String `
    -Label "Menu response delay"

Set-RegistrySetting `
    -Path $WindowMetricsPath `
    -Name "MinAnimate" `
    -Value "0" `
    -Type String `
    -Label "Window minimize animation"

Set-RegistrySetting `
    -Path `
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
    -Name "VisualFXSetting" `
    -Value 2 `
    -Type DWord `
    -Label "Visual effects preference"

Write-Section "Filesystem"

if (Test-IsAdministrator) {
    Set-RegistrySetting `
        -Path `
            "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
        -Name "LongPathsEnabled" `
        -Value 1 `
        -Type DWord `
        -Label "Long file paths"
}
else {
    Record-Warn "Long file paths" `
        "requires an elevated PowerShell session"
}

Write-Section "Applying Settings"

try {
    Stop-Process `
        -Name explorer `
        -Force `
        -ErrorAction SilentlyContinue

    Start-Process explorer.exe

    Record-OK "Explorer restart" "complete"
}
catch {
    Record-Warn "Explorer restart" `
        "log off or restart to apply every setting"
}

Write-Section "Settings Result"

Write-InfoLine "Changes applied" $Changes.ToString()
Write-InfoLine "Warnings" $Warnings.ToString()
Write-InfoLine "Failures" $Failures.ToString()

Add-ReportLine ""
Add-ReportLine "Changes applied: $Changes"
Add-ReportLine "Warnings: $Warnings"
Add-ReportLine "Failures: $Failures"

if ($Failures -eq 0) {
    Write-OK "Overall status" "PASS"
    Add-ReportLine "Overall status: PASS"
}
else {
    Write-Fail "Overall status" "INCOMPLETE"
    Add-ReportLine "Overall status: INCOMPLETE"
}

Write-InfoLine "Report" $Report
Write-InfoLine "Backup" $BackupRoot

Add-ReportLine "Report: $Report"
Add-ReportLine "Backup: $BackupRoot"

if ($Failures -gt 0) {
    exit 1
}

exit 0
