param([switch]$DryRun)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$Report = New-TimestampedReport -RootDirectory $Root -Prefix "filesystem-compat" -DryRun:$DryRun
$Warnings = 0

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

function Record-Info {
    param([string]$Label, [string]$Message)
    Write-InfoLine $Label $Message
    Add-ReportLine ("[INFO] {0,-28} {1}" -f $Label, $Message)
}

Add-ReportLine "Windows Cross-Filesystem Compatibility"
Add-ReportLine "======================================"
Add-ReportLine "Run date: $(Get-Date)"
Add-ReportLine ""

Write-Section "ext4 Access"

$WslCommand = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $WslCommand) {
    Record-Warn "WSL" "not available; ext4 access is not configured"
}
else {
    $WslHelp = (& $WslCommand.Source --help 2>&1) -join "`n"
    if ($WslHelp -match '--mount') {
        Record-OK "WSL disk mounting" "wsl --mount is available"
        Record-Info "ext4 workflow" "attach an offline whole disk with elevated wsl --mount; unmount before reboot"
        Record-Warn "Read-only mounts" "wsl --mount does not accept generic ro; use --bare and mount read-only inside Linux"
    }
    else {
        Record-Warn "WSL disk mounting" "installed WSL does not expose wsl --mount; Windows 11 or Store WSL is required"
    }
}

Record-Info "Safety boundary" "never attach the active Windows disk; WSL attaches an entire offline disk"
Record-Info "USB limitation" "wsl --mount does not directly support typical USB flash/SD readers"

Write-Section "APFS Access"

Record-Warn "Native APFS support" "Windows has no Microsoft-supplied APFS filesystem driver"
Record-Info "Recommended access" "use macOS file sharing, an exFAT exchange volume, or copy through the network"
Record-Info "Third-party drivers" "not installed automatically; evaluate read-only tooling manually before trusting data"

Write-Section "Shared NTFS Safety"

$PowerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
$HiberbootEnabled = Get-ItemPropertyValue -LiteralPath $PowerPath -Name "HiberbootEnabled" -ErrorAction SilentlyContinue
if ($HiberbootEnabled -eq 0) {
    Record-OK "Fast Startup" "disabled"
}
else {
    Record-Warn "Fast Startup" "enabled or indeterminate; run cleanup elevated before cross-OS NTFS writes"
}
Record-Info "Operating-system switch" "perform a full Windows shutdown before mounting its NTFS volumes elsewhere"

Write-Section "Filesystem Compatibility Result"
Write-InfoLine "Warnings" $Warnings.ToString()
Write-OK "Overall status" "GUIDANCE COMPLETE"
if ($Report) { Write-InfoLine "Report" $Report } else { Write-InfoLine "Report" "suppressed in dry-run mode" }

Add-ReportLine ""
Add-ReportLine "Warnings: $Warnings"
Add-ReportLine "Overall status: GUIDANCE COMPLETE"
exit 0
