Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$Report = New-TimestampedReport `
    -RootDirectory $Root `
    -Prefix "preflight"

$Failures = 0
$Warnings = 0

function Add-ReportLine {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    $Text | Add-Content -Encoding UTF8 $Report
}

function Record-OK {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-OK $Label $Message
    Add-ReportLine ("[ OK ] {0,-28} {1}" -f $Label, $Message)
}

function Record-Warn {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $script:Warnings++
    Write-Warn $Label $Message
    Add-ReportLine ("[WARN] {0,-28} {1}" -f $Label, $Message)
}

function Record-Fail {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $script:Failures++
    Write-Fail $Label $Message
    Add-ReportLine ("[FAIL] {0,-28} {1}" -f $Label, $Message)
}

"Windows Bootstrap Preflight" | Set-Content -Encoding UTF8 $Report
"===========================" | Add-Content $Report
"Run date: $(Get-Date)" | Add-Content $Report
"" | Add-Content $Report

Write-Section "Windows Bootstrap Preflight"

Record-OK "Run date" (Get-Date).ToString()
Record-OK "User" $env:USERNAME
Record-OK "Computer" $env:COMPUTERNAME

Write-Section "PowerShell"

if ($PSVersionTable.PSVersion.Major -ge 7) {
    Record-OK "PowerShell version" $PSVersionTable.PSVersion.ToString()
}
else {
    Record-Fail "PowerShell version" `
        "PowerShell 7 or newer is required; found $($PSVersionTable.PSVersion)"
}

if ([Environment]::Is64BitProcess) {
    Record-OK "PowerShell architecture" "64-bit"
}
else {
    Record-Fail "PowerShell architecture" "32-bit process detected"
}

Write-Section "Windows"

$OperatingSystem = Get-CimInstance Win32_OperatingSystem
$ComputerSystem = Get-CimInstance Win32_ComputerSystem

Record-OK "Windows edition" $OperatingSystem.Caption
Record-OK "Windows version" $OperatingSystem.Version
Record-OK "Windows build" $OperatingSystem.BuildNumber
Record-OK "System architecture" $OperatingSystem.OSArchitecture
Record-OK "Manufacturer" $ComputerSystem.Manufacturer
Record-OK "Model" $ComputerSystem.Model

$ReviMarkers = @(
    "C:\Program Files\Revision Tool",
    "C:\ProgramData\Revision",
    "C:\ProgramData\ReviOS"
)

$DetectedReviMarker = Test-ApplicationPath -Paths $ReviMarkers

if ($DetectedReviMarker) {
    Record-Warn "ReviOS" "Detected at $DetectedReviMarker"
}
else {
    Record-OK "ReviOS marker" "No standard marker detected"
}

Write-Section "Required Tools"

if (Test-CommandAvailable "winget") {
    Record-OK "WinGet" ((winget --version) -join " ")
}
else {
    Record-Fail "WinGet" "command not found"
}

if (Test-CommandAvailable "git") {
    Record-OK "Git" ((git --version) -join " ")
}
else {
    Record-Fail "Git" "command not found"
}

if (Test-CommandAvailable "pwsh") {
    $PwshPath = (Get-Command pwsh).Source
    Record-OK "pwsh executable" $PwshPath
}
else {
    Record-Fail "pwsh executable" "command not found"
}

$TerminalPaths = @(
    "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe",
    "$env:ProgramFiles\WindowsApps\Microsoft.WindowsTerminal*\wt.exe",
    "$env:LOCALAPPDATA\Programs\Windows Terminal\wt.exe"
)

$TerminalCommand = Get-Command wt -ErrorAction SilentlyContinue

if ($TerminalCommand) {
    Record-OK "Windows Terminal" $TerminalCommand.Source
}
else {
    $TerminalPath = Test-ApplicationPath -Paths $TerminalPaths

    if ($TerminalPath) {
        Record-OK "Windows Terminal" $TerminalPath
    }
    else {
        Record-Warn "Windows Terminal" "not found or AppX registration is broken"
    }
}

Write-Section "Storage"

$SystemDriveLetter = $env:SystemDrive.TrimEnd(":")
$SystemVolume = Get-Volume -DriveLetter $SystemDriveLetter
$FreeGB = [math]::Round($SystemVolume.SizeRemaining / 1GB, 1)
$TotalGB = [math]::Round($SystemVolume.Size / 1GB, 1)

Record-OK "System drive" "$($SystemVolume.DriveLetter):"
Record-OK "Drive capacity" "$TotalGB GB"
Record-OK "Free space" "$FreeGB GB"

if ($FreeGB -ge 20) {
    Record-OK "Disk-space check" "PASS"
}
elseif ($FreeGB -ge 5) {
    Record-Warn "Disk-space check" `
        "Only $FreeGB GB free on the intentionally small Windows partition"
}
else {
    Record-Fail "Disk-space check" "Less than 5 GB free"
}

Write-Section "Connectivity"

if (Test-InternetConnection) {
    Record-OK "Internet" "TCP 443 reachable"
}
else {
    Record-Fail "Internet" "Unable to reach www.microsoft.com:443"
}

try {
    $DnsResult = Resolve-DnsName `
        -Name "www.microsoft.com" `
        -Type A `
        -ErrorAction Stop

    $DnsAddress = $DnsResult |
        ForEach-Object {
            if ($_.PSObject.Properties.Name -contains "IPAddress") {
                $_.IPAddress
            }
            elseif ($_.PSObject.Properties.Name -contains "IP4Address") {
                $_.IP4Address
            }
        } |
        Where-Object { $_ } |
        Select-Object -First 1

    if ($DnsAddress) {
        Record-OK "DNS" $DnsAddress.ToString()
    }
    else {
        Record-OK "DNS" "resolution succeeded"
    }
}
catch {
    Record-Fail "DNS" $_.Exception.Message
}

Write-Section "Permissions"

if (Test-IsAdministrator) {
    Record-OK "Administrator" "current shell is elevated"
}
else {
    Record-Warn "Administrator" `
        "current shell is not elevated; install modules may prompt later"
}

Write-Section "Repository"

if (Test-Path $Root) {
    Record-OK "Repository path" $Root
}
else {
    Record-Fail "Repository path" "missing"
}

$WriteTest = Join-Path $Root ".preflight-write-test"

try {
    "test" | Set-Content -Encoding UTF8 $WriteTest
    Remove-Item $WriteTest -Force
    Record-OK "Repository writable" "PASS"
}
catch {
    Record-Fail "Repository writable" $_.Exception.Message
}

foreach ($Directory in @("modules", "profiles", "reports", "backups")) {
    $Path = Join-Path $Root $Directory

    if (Test-Path $Path) {
        Record-OK "$Directory directory" $Path
    }
    else {
        Record-Fail "$Directory directory" "missing"
    }
}

Write-Section "Preflight Result"

Write-InfoLine "Warnings" $Warnings.ToString()
Write-InfoLine "Failures" $Failures.ToString()

Add-ReportLine ""
Add-ReportLine "Warnings: $Warnings"
Add-ReportLine "Failures: $Failures"

if ($Failures -eq 0) {
    Write-OK "Overall status" "PASS"
    Add-ReportLine "Overall status: PASS"
}
else {
    Write-Fail "Overall status" "FAIL"
    Add-ReportLine "Overall status: FAIL"
}

Write-InfoLine "Report" $Report
Add-ReportLine "Report: $Report"

if ($Failures -gt 0) {
    exit 1
}

exit 0

