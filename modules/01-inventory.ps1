Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BackupRoot = Join-Path $Root "backups\inventory-$Timestamp"
$Report = Join-Path $Root "reports\inventory-$Timestamp.txt"

New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null

$Warnings = 0

function Add-ReportLine {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    $Text | Add-Content -Encoding UTF8 $Report
}

function Save-Inventory {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [scriptblock]$Command,

        [Parameter(Mandatory)]
        [string]$FileName
    )

    $Path = Join-Path $BackupRoot $FileName

    try {
        & $Command |
            Out-File -Encoding UTF8 -Width 4096 $Path

        Write-OK $Label $Path
        Add-ReportLine ("[ OK ] {0,-28} {1}" -f $Label, $Path)
    }
    catch {
        $script:Warnings++
        Write-Warn $Label $_.Exception.Message
        Add-ReportLine ("[WARN] {0,-28} {1}" -f $Label, $_.Exception.Message)
    }
}

"Windows Bootstrap Inventory" | Set-Content -Encoding UTF8 $Report
"===========================" | Add-Content $Report
"Run date: $(Get-Date)" | Add-Content $Report
"Computer: $env:COMPUTERNAME" | Add-Content $Report
"User: $env:USERNAME" | Add-Content $Report
"Backup: $BackupRoot" | Add-Content $Report
"" | Add-Content $Report

Write-Section "Windows Bootstrap Inventory"
Write-InfoLine "Backup directory" $BackupRoot

Write-Section "System"

Save-Inventory "Computer information" {
    Get-ComputerInfo | Format-List *
} "computer-info.txt"

Save-Inventory "Operating system" {
    Get-CimInstance Win32_OperatingSystem | Format-List *
} "operating-system.txt"

Save-Inventory "Computer hardware" {
    Get-CimInstance Win32_ComputerSystem | Format-List *
} "computer-system.txt"

Save-Inventory "Processor" {
    Get-CimInstance Win32_Processor | Format-List *
} "processor.txt"

Save-Inventory "Memory" {
    Get-CimInstance Win32_PhysicalMemory |
        Select-Object Manufacturer, Capacity, Speed, PartNumber |
        Format-Table -AutoSize
} "memory.txt"

Save-Inventory "BIOS" {
    Get-CimInstance Win32_BIOS | Format-List *
} "bios.txt"

Write-Section "Storage"

Save-Inventory "Volumes" {
    Get-Volume |
        Sort-Object DriveLetter |
        Select-Object DriveLetter, FileSystemLabel, FileSystem, HealthStatus,
            Size, SizeRemaining |
        Format-Table -AutoSize
} "volumes.txt"

Save-Inventory "Physical disks" {
    Get-PhysicalDisk |
        Select-Object FriendlyName, MediaType, BusType, HealthStatus,
            OperationalStatus, Size |
        Format-Table -AutoSize
} "physical-disks.txt"

Save-Inventory "Partitions" {
    Get-Partition |
        Sort-Object DiskNumber, PartitionNumber |
        Format-Table DiskNumber, PartitionNumber, DriveLetter, Type, Size -AutoSize
} "partitions.txt"

Write-Section "Installed Applications"

Save-Inventory "WinGet packages" {
    winget list
} "winget-packages.txt"

Save-Inventory "Installed packages" {
    Get-Package |
        Sort-Object Name |
        Select-Object Name, Version, ProviderName, Source |
        Format-Table -AutoSize
} "packages.txt"

Save-Inventory "AppX packages" {
    Get-AppxPackage |
        Sort-Object Name |
        Select-Object Name, Version, PackageFullName, InstallLocation |
        Format-Table -AutoSize
} "appx-packages.txt"

Save-Inventory "Uninstall registry" {
    $RegistryPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    Get-ItemProperty $RegistryPaths -ErrorAction SilentlyContinue |
        Where-Object DisplayName |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallLocation,
            UninstallString |
        Sort-Object DisplayName |
        Format-Table -AutoSize
} "uninstall-registry.txt"

Write-Section "Startup and Background Activity"

Save-Inventory "Startup commands" {
    Get-CimInstance Win32_StartupCommand |
        Sort-Object Name |
        Select-Object Name, Command, Location, User |
        Format-Table -AutoSize
} "startup-commands.txt"

Save-Inventory "Automatic services" {
    Get-Service |
        Where-Object StartType -eq "Automatic" |
        Sort-Object Name |
        Select-Object Status, Name, DisplayName, StartType |
        Format-Table -AutoSize
} "automatic-services.txt"

Save-Inventory "All services" {
    Get-Service |
        Sort-Object Name |
        Select-Object Status, Name, DisplayName, StartType |
        Format-Table -AutoSize
} "all-services.txt"

Save-Inventory "Scheduled tasks" {
    Get-ScheduledTask |
        Sort-Object TaskPath, TaskName |
        Select-Object TaskPath, TaskName, State, Author |
        Format-Table -AutoSize
} "scheduled-tasks.txt"

Write-Section "Windows Features"

Save-Inventory "Optional features" {
    Get-WindowsOptionalFeature -Online |
        Sort-Object FeatureName |
        Select-Object FeatureName, State |
        Format-Table -AutoSize
} "optional-features.txt"

Save-Inventory "Windows capabilities" {
    Get-WindowsCapability -Online |
        Sort-Object Name |
        Select-Object Name, State |
        Format-Table -AutoSize
} "windows-capabilities.txt"

Write-Section "Networking"

Save-Inventory "Network adapters" {
    Get-NetAdapter |
        Sort-Object Name |
        Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress |
        Format-Table -AutoSize
} "network-adapters.txt"

Save-Inventory "IP configuration" {
    Get-NetIPConfiguration | Format-List *
} "ip-configuration.txt"

Save-Inventory "DNS servers" {
    Get-DnsClientServerAddress |
        Select-Object InterfaceAlias, AddressFamily, ServerAddresses |
        Format-Table -AutoSize
} "dns-servers.txt"

Save-Inventory "Routes" {
    Get-NetRoute |
        Sort-Object InterfaceIndex, DestinationPrefix |
        Select-Object InterfaceIndex, DestinationPrefix, NextHop, RouteMetric,
            State |
        Format-Table -AutoSize
} "routes.txt"

Save-Inventory "Firewall profiles" {
    Get-NetFirewallProfile |
        Format-List *
} "firewall-profiles.txt"

Write-Section "Shell and Environment"

Save-Inventory "PowerShell version" {
    $PSVersionTable | Format-List *
} "powershell-version.txt"

Save-Inventory "Execution policy" {
    Get-ExecutionPolicy -List | Format-Table -AutoSize
} "execution-policy.txt"

Save-Inventory "Environment variables" {
    Get-ChildItem Env: |
        Sort-Object Name |
        Format-Table Name, Value -AutoSize
} "environment-variables.txt"

Save-Inventory "User PATH" {
    [Environment]::GetEnvironmentVariable("Path", "User")
} "user-path.txt"

Save-Inventory "Machine PATH" {
    [Environment]::GetEnvironmentVariable("Path", "Machine")
} "machine-path.txt"

Write-Section "Boot and Power"

Save-Inventory "Boot configuration" {
    bcdedit /enum all
} "boot-configuration.txt"

Save-Inventory "Power configuration" {
    powercfg /getactivescheme
    powercfg /query
} "power-configuration.txt"

Write-Section "Inventory Result"

Write-InfoLine "Warnings" $Warnings.ToString()
Write-OK "Overall status" "COMPLETE"
Write-InfoLine "Report" $Report
Write-InfoLine "Backup" $BackupRoot

Add-ReportLine ""
Add-ReportLine "Warnings: $Warnings"
Add-ReportLine "Overall status: COMPLETE"
Add-ReportLine "Report: $Report"
Add-ReportLine "Backup: $BackupRoot"

exit 0
