Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$Report = New-TimestampedReport -RootDirectory $Root -Prefix "audit"
$Warnings = 0
$CollectionErrors = 0

function Add-AuditLine {
    param([AllowEmptyString()][string]$Text)
    $Text | Add-Content -Encoding UTF8 $Report
}

function Add-AuditSection {
    param([string]$Title)
    Add-AuditLine ""
    Add-AuditLine $Title
    Add-AuditLine ("=" * $Title.Length)
}

function Record-AuditInfo {
    param([string]$Label, [string]$Message)
    Write-InfoLine $Label $Message
    Add-AuditLine ("[INFO] {0,-28} {1}" -f $Label, $Message)
}

function Record-AuditOK {
    param([string]$Label, [string]$Message)
    Write-OK $Label $Message
    Add-AuditLine ("[ OK ] {0,-28} {1}" -f $Label, $Message)
}

function Record-AuditWarn {
    param([string]$Label, [string]$Message)
    $script:Warnings++
    Write-Warn $Label $Message
    Add-AuditLine ("[WARN] {0,-28} {1}" -f $Label, $Message)
}

function Invoke-AuditCollection {
    param(
        [string]$Label,
        [scriptblock]$Action
    )

    try {
        & $Action
    }
    catch {
        $script:CollectionErrors++
        Record-AuditWarn $Label "collection unavailable"
        Add-AuditLine ("       {0}" -f $_.Exception.Message)
    }
}

"LarryBootstrap Windows System Audit" | Set-Content -Encoding UTF8 $Report
"=====================================" | Add-Content $Report
Add-AuditLine "Run date: $(Get-Date)"
Add-AuditLine "Computer: $env:COMPUTERNAME"
Add-AuditLine "User: $env:USERNAME"

Write-Section "System Audit"
Record-AuditInfo "Report" ([IO.Path]::GetFileName($Report))

Add-AuditSection "System"
Invoke-AuditCollection "System" {
    $OS = Get-CimInstance Win32_OperatingSystem
    $Computer = Get-CimInstance Win32_ComputerSystem
    $Uptime = (Get-Date) - $OS.LastBootUpTime
    $MemoryGB = [math]::Round($Computer.TotalPhysicalMemory / 1GB, 1)

    Record-AuditInfo "Operating system" "$($OS.Caption) $($OS.Version) (build $($OS.BuildNumber))"
    Record-AuditInfo "Uptime" ("{0}d {1}h {2}m" -f $Uptime.Days, $Uptime.Hours, $Uptime.Minutes)
    Record-AuditInfo "Memory" "$MemoryGB GB installed"
}

Add-AuditSection "Storage"
Invoke-AuditCollection "Storage" {
    $Volumes = @(Get-Volume | Where-Object DriveLetter | Sort-Object DriveLetter)
    foreach ($Volume in $Volumes) {
        $FreePercent = if ($Volume.Size -gt 0) {
            [math]::Round(($Volume.SizeRemaining / $Volume.Size) * 100, 1)
        }
        else { 0 }
        $FreeGB = [math]::Round($Volume.SizeRemaining / 1GB, 1)
        $Message = "$FreeGB GB free ($FreePercent%)"

        if ($FreePercent -lt 10) {
            Record-AuditWarn "Drive $($Volume.DriveLetter):" $Message
        }
        else {
            Record-AuditOK "Drive $($Volume.DriveLetter):" $Message
        }
    }
}

Add-AuditSection "Networking"
Invoke-AuditCollection "Networking" {
    $Configurations = @(Get-NetIPConfiguration |
        Where-Object { $_.IPv4Address -and $_.NetAdapter.Status -eq "Up" })
    Record-AuditInfo "Active adapters" $Configurations.Count.ToString()
    foreach ($Configuration in $Configurations) {
        $Address = ($Configuration.IPv4Address.IPAddress | Select-Object -First 1)
        Add-AuditLine ("{0}: {1}" -f $Configuration.InterfaceAlias, $Address)
    }
}

Add-AuditSection "Services"
Invoke-AuditCollection "Services" {
    $StoppedAutomatic = @(Get-Service |
        Where-Object { $_.StartType -eq "Automatic" -and $_.Status -ne "Running" } |
        Sort-Object DisplayName)
    if ($StoppedAutomatic.Count -eq 0) {
        Record-AuditOK "Automatic services" "all running"
    }
    else {
        Record-AuditWarn "Automatic services" "$($StoppedAutomatic.Count) stopped"
        $StoppedAutomatic | Select-Object -First 20 |
            ForEach-Object { Add-AuditLine ("Stopped: {0} ({1})" -f $_.DisplayName, $_.Name) }
    }
}

Add-AuditSection "Recent Events"
Invoke-AuditCollection "Event logs" {
    $Since = (Get-Date).AddHours(-24)
    foreach ($LogName in @("System", "Application")) {
        $Events = @(Get-WinEvent -FilterHashtable @{
                LogName = $LogName
                Level = 1, 2, 3
                StartTime = $Since
            } -ErrorAction SilentlyContinue)
        $Errors = @($Events | Where-Object Level -in 1, 2)
        $EventWarnings = @($Events | Where-Object Level -eq 3)
        $Message = "$($Errors.Count) errors, $($EventWarnings.Count) warnings in 24h"
        if ($Errors.Count -gt 0) {
            Record-AuditWarn "$LogName log" $Message
        }
        else {
            Record-AuditOK "$LogName log" $Message
        }

        $Events | Select-Object -First 30 |
            ForEach-Object {
                $Summary = ([string]$_.Message -replace '\s+', ' ').Trim()
                Add-AuditLine ("{0:u} ID {1}: {2}" -f $_.TimeCreated, $_.Id, $Summary)
            }
    }
}

Add-AuditSection "Startup and Reboot"
Invoke-AuditCollection "Startup" {
    $Startup = @(Get-CimInstance Win32_StartupCommand)
    Record-AuditInfo "Startup commands" $Startup.Count.ToString()
    $Startup | Sort-Object Name |
        ForEach-Object { Add-AuditLine ("{0} [{1}]" -f $_.Name, $_.Location) }
}

$RebootKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
)
$PendingReboot = $false
foreach ($Key in $RebootKeys) {
    if (Test-Path -LiteralPath $Key) {
        $PendingReboot = $true
        break
    }
}
if ($PendingReboot) {
    Record-AuditWarn "Pending reboot" "Windows is waiting for a restart"
}
else {
    Record-AuditOK "Pending reboot" "none detected"
}

Add-AuditSection "Security"
Invoke-AuditCollection "Windows Security" {
    $Defender = Get-MpComputerStatus -ErrorAction Stop
    if ($Defender.AntivirusEnabled -and $Defender.RealTimeProtectionEnabled) {
        Record-AuditOK "Microsoft Defender" "antivirus and real-time protection enabled"
    }
    else {
        Record-AuditWarn "Microsoft Defender" "one or more protections disabled"
    }
    Record-AuditInfo "Signature age" "$($Defender.AntivirusSignatureAge) day(s)"
}

Write-Section "Audit Result"
Write-InfoLine "Warnings" $Warnings.ToString()
Write-InfoLine "Collection errors" $CollectionErrors.ToString()
Write-OK "Overall status" "COMPLETE"
Write-InfoLine "Report" ([IO.Path]::GetFileName($Report))

Add-AuditSection "Result"
Add-AuditLine "Warnings: $Warnings"
Add-AuditLine "Collection errors: $CollectionErrors"
Add-AuditLine "Overall status: COMPLETE"
Add-AuditLine "Report: $Report"

Invoke-BootstrapArtifactRetention -RootDirectory $Root -KeepPerModule 3
exit 0
