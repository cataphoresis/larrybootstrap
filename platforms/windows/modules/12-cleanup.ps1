param([switch]$DryRun)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$Report = New-TimestampedReport -RootDirectory $Root -Prefix "cleanup" -DryRun:$DryRun
$Failures = 0
$Removed = 0
$AlreadyClean = 0
$Planned = 0

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
    Write-Warn $Label $Message
    Add-ReportLine ("[WARN] {0,-28} {1}" -f $Label, $Message)
}

function Record-Fail {
    param([string]$Label, [string]$Message)
    $script:Failures++
    Write-Fail $Label $Message
    Add-ReportLine ("[FAIL] {0,-28} {1}" -f $Label, $Message)
}

function Get-ParsecUninstallEntries {
    $RegistryPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    @(
        Get-ItemProperty $RegistryPaths -ErrorAction SilentlyContinue |
            Where-Object {
                $_.PSObject.Properties.Name -contains "DisplayName" -and
                $_.PSObject.Properties.Name -contains "Publisher" -and
                [string]$_.DisplayName -match '^Parsec($| )' -and
                [string]$_.Publisher -match '^Parsec Cloud Inc\.?$'
            } |
            Sort-Object { if ($_.DisplayName -eq "Parsec") { 1 } else { 0 } }
    )
}

function Invoke-RegisteredParsecUninstall {
    param([Parameter(Mandatory)][pscustomobject]$Entry)

    $HasQuietCommand = (
        $Entry.PSObject.Properties.Name -contains "QuietUninstallString" -and
        -not [string]::IsNullOrWhiteSpace([string]$Entry.QuietUninstallString)
    )

    $RawCommand = if ($HasQuietCommand) {
        [string]$Entry.QuietUninstallString
    }
    else {
        [string]$Entry.UninstallString
    }

    if ([string]::IsNullOrWhiteSpace($RawCommand)) {
        throw "registered uninstall command is missing"
    }

    $Match = [regex]::Match($RawCommand, '^\s*"(?<exe>[^"]+)"(?<args>.*)$')
    if (-not $Match.Success) {
        $Match = [regex]::Match($RawCommand, '^\s*(?<exe>\S+)(?<args>.*)$')
    }

    if (-not $Match.Success) {
        throw "could not parse registered uninstall command"
    }

    $Executable = [Environment]::ExpandEnvironmentVariables($Match.Groups['exe'].Value)
    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
        throw "registered uninstaller not found: $Executable"
    }

    $ProgramFilesRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { [IO.Path]::GetFullPath($_).TrimEnd('\') + '\' }
    $ResolvedExecutable = [IO.Path]::GetFullPath($Executable)

    if (-not ($ProgramFilesRoots | Where-Object { $ResolvedExecutable.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) })) {
        throw "refusing uninstaller outside Program Files: $ResolvedExecutable"
    }

    $Signature = Get-AuthenticodeSignature -LiteralPath $ResolvedExecutable
    if ($Signature.Status -ne "Valid") {
        throw "uninstaller signature is $($Signature.Status), expected Valid"
    }

    $Signer = [string]$Signature.SignerCertificate.Subject
    if ($Signer -notmatch 'Parsec Cloud|Unity Technologies') {
        throw "refusing unexpected uninstaller signer: $Signer"
    }

    $Arguments = $Match.Groups['args'].Value.Trim()
    if (-not $HasQuietCommand) {
        $Arguments = (($Arguments, "/silent") -join " ").Trim()
    }

    $Process = Start-Process -FilePath $ResolvedExecutable -ArgumentList $Arguments -Wait -PassThru
    if ($Process.ExitCode -notin @(0, 3010, 350)) {
        throw "uninstaller exited with code $($Process.ExitCode)"
    }
}

Add-ReportLine "Windows Retired Application Cleanup"
Add-ReportLine "==================================="
Add-ReportLine "Run date: $(Get-Date)"
Add-ReportLine ""

Write-Section "Retired Application Cleanup"

$ParsecEntries = @(Get-ParsecUninstallEntries)
if ($ParsecEntries.Count -eq 0) {
    $AlreadyClean++
    Record-OK "Parsec components" "not installed"
}
elseif ($DryRun) {
    foreach ($Entry in $ParsecEntries) {
        $Planned++
        Write-InfoLine ([string]$Entry.DisplayName) "would uninstall version $($Entry.DisplayVersion)"
    }
}
elseif (-not (Test-IsAdministrator)) {
    Record-Fail "Parsec components" "removal requires an elevated PowerShell session"
}
else {
    Get-Process parsecd, pservice -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    foreach ($Entry in $ParsecEntries) {
        try {
            Invoke-RegisteredParsecUninstall -Entry $Entry
            $Removed++
            Record-OK ([string]$Entry.DisplayName) "uninstaller completed"
        }
        catch {
            Record-Fail ([string]$Entry.DisplayName) $_.Exception.Message
        }
    }
}

$ParsecDataPaths = @(
    (Join-Path $env:APPDATA "Parsec"),
    (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Parsec"),
    (Join-Path $env:ProgramData "Parsec"),
    (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\Parsec")
)
$ExistingParsecData = @($ParsecDataPaths | Where-Object { Test-Path -LiteralPath $_ })

if ($ExistingParsecData.Count -eq 0) {
    $AlreadyClean++
    Record-OK "Parsec user data" "not present"
}
elseif ($DryRun) {
    $Planned += $ExistingParsecData.Count
    Write-InfoLine "Parsec user data" "would remove $($ExistingParsecData.Count) known path(s) after uninstall"
}
elseif ((Get-ParsecUninstallEntries).Count -gt 0) {
    Record-Warn "Parsec user data" "preserved because installed components remain"
}
else {
    foreach ($Path in $ExistingParsecData) {
        Remove-Item -LiteralPath $Path -Recurse -Force
        $Removed++
        Record-OK "Parsec data" "removed $Path"
    }
}

Write-Section "Fast Startup Compatibility"

$PowerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
$HiberbootEnabled = Get-ItemPropertyValue -LiteralPath $PowerPath -Name "HiberbootEnabled" -ErrorAction SilentlyContinue

if ($HiberbootEnabled -eq 0) {
    $AlreadyClean++
    Record-OK "Fast Startup" "disabled; safe for shared NTFS access"
}
elseif ($DryRun) {
    $Planned++
    Write-InfoLine "Fast Startup" "would disable HiberbootEnabled for safer cross-OS NTFS access"
}
elseif (-not (Test-IsAdministrator)) {
    Record-Fail "Fast Startup" "disablement requires an elevated PowerShell session"
}
else {
    $BackupRoot = Join-Path $Root ("backups\cleanup-{0}" -f (Get-Date -Format "yyyy-MM-dd_HH-mm-ss"))
    New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
    $BackupPath = Join-Path $BackupRoot "power.reg"
    & reg.exe export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" $BackupPath /y 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Record-Fail "Fast Startup backup" "could not export the power registry key"
    }
    else {
        Record-OK "Fast Startup backup" $BackupPath
    }

    if ($Failures -gt 0) {
        Write-Section "Cleanup Result"
        Write-Fail "Overall status" "INCOMPLETE"
        if ($Report) { Write-InfoLine "Report" $Report }
        exit 1
    }

    New-ItemProperty -LiteralPath $PowerPath -Name "HiberbootEnabled" -Value 0 -PropertyType DWord -Force | Out-Null
    $Removed++
    Record-OK "Fast Startup" "disabled; restart Windows before accessing NTFS from another OS"
}

$PowerStateText = (powercfg.exe /availableSleepStates 2>&1) -join "`n"
$AvailablePowerStateText = ($PowerStateText -split '(?im)^The following sleep states are not available')[0]
$HibernateAvailable = $AvailablePowerStateText -match '(?im)^\s*Hibernate\s*$'
if ($HibernateAvailable) {
    Record-Warn "Hibernation" "still available; use a full shutdown before switching operating systems"
}
else {
    Record-OK "Hibernation" "not available"
}

Write-Section "Cleanup Result"
Write-InfoLine "Already clean" $AlreadyClean.ToString()
Write-InfoLine $(if ($DryRun) { "Actions planned" } else { "Items removed/changed" }) $(if ($DryRun) { $Planned.ToString() } else { $Removed.ToString() })
Write-InfoLine "Failures" $Failures.ToString()

if ($Failures -eq 0) { Write-OK "Overall status" "COMPLETE" } else { Write-Fail "Overall status" "INCOMPLETE" }
if ($Report) { Write-InfoLine "Report" $Report } else { Write-InfoLine "Report" "suppressed in dry-run mode" }

Add-ReportLine ""
Add-ReportLine "Already clean: $AlreadyClean"
Add-ReportLine "Removed or changed: $Removed"
Add-ReportLine "Planned: $Planned"
Add-ReportLine "Failures: $Failures"

if ($Failures -gt 0) { exit 1 }
exit 0
