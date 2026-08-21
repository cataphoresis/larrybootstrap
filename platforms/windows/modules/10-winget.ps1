param(
    [ValidateSet("standard")]
    [string]$Profile = "standard",

    [switch]$DryRun,

    [string]$DeferredStatePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$ManifestPath = Join-Path `
    $Root `
    "profiles\packages-$Profile.txt"

$Report = New-TimestampedReport `
    -RootDirectory $Root `
    -Prefix "winget" `
    -DryRun:$DryRun

$Installed = 0
$Present = 0
$RequiredFailures = 0
$OptionalFailures = 0
$DeferredFailures = 0
$DeferredPackageIds = [Collections.Generic.List[string]]::new()

function Add-ReportLine {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ($Report) { $Text | Add-Content -Encoding UTF8 $Report }
}

Add-ReportLine "Windows Bootstrap WinGet Installation"
Add-ReportLine "======================================="
Add-ReportLine "Run date: $(Get-Date)"
Add-ReportLine "Profile: $Profile"
Add-ReportLine "Manifest: $ManifestPath"
Add-ReportLine ""

Write-Section "Windows Package Installation"

Write-InfoLine "Profile" $Profile
Write-InfoLine "Manifest" $ManifestPath
$SystemVolume = Get-SystemVolumeInfo
Write-InfoLine "Free space" (
    "{0:N1} GB" -f (
        $SystemVolume.SizeRemaining /
        1GB
    )
)

if (-not (Test-CommandAvailable "winget")) {
    Write-Fail "WinGet" "command not found"
    Add-ReportLine "[FAIL] WinGet command not found"
    exit 1
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Write-Fail "Manifest" "not found: $ManifestPath"
    Add-ReportLine "[FAIL] Manifest not found"
    exit 1
}

$Packages = @(
    Get-PackageManifest -Path $ManifestPath
)

Write-OK "Manifest entries" $Packages.Count.ToString()
Add-ReportLine "Manifest entries: $($Packages.Count)"

Write-Section "Refreshing WinGet Sources"

if ($DryRun) {
    Write-InfoLine "WinGet sources" "would refresh; skipped in dry-run mode"
}
else {
    try {
        winget source update --disable-interactivity

        if ($LASTEXITCODE -eq 0) {
            Write-OK "WinGet sources" "updated"
            Add-ReportLine "[ OK ] WinGet sources updated"
        }
        else {
            Write-Warn "WinGet sources" `
                "update returned code $LASTEXITCODE; continuing"

            Add-ReportLine `
                "[WARN] WinGet source update returned code $LASTEXITCODE"
        }
    }
    catch {
        Write-Warn "WinGet sources" `
            "update failed; continuing with current metadata"

        Add-ReportLine `
            "[WARN] WinGet source update failed: $($_.Exception.Message)"
    }
}

Write-Section "Applications"

foreach ($Package in $Packages) {
    Write-InfoLine "Checking" $Package.DisplayName

    $WasInstalled = Test-WinGetPackageInstalled -Id $Package.Id

    if ($WasInstalled) {
        Write-OK $Package.DisplayName "already installed"
        Add-ReportLine (
            "[ OK ] {0,-28} already installed ({1})" -f
            $Package.DisplayName,
            $Package.Id
        )

        $Present++
        continue
    }

    $Result = Install-WinGetPackage -Package $Package -DryRun:$DryRun

    if ($Result) {
        Add-ReportLine (
            "[ OK ] {0,-28} installed ({1})" -f
            $Package.DisplayName,
            $Package.Id
        )

        $Installed++
        continue
    }

    if ($script:LastWinGetInstallRecoverable) {
        Add-ReportLine (
            "[WARN] {0,-28} deferred download failure ({1})" -f
            $Package.DisplayName,
            $Package.Id
        )
        $DeferredFailures++
        $DeferredPackageIds.Add($Package.Id)
    }
    elseif ($Package.Required) {
        Add-ReportLine (
            "[FAIL] {0,-28} required installation failed ({1})" -f
            $Package.DisplayName,
            $Package.Id
        )

        $RequiredFailures++
    }
    else {
        Add-ReportLine (
            "[WARN] {0,-28} optional installation failed ({1})" -f
            $Package.DisplayName,
            $Package.Id
        )

        $OptionalFailures++
    }
}

Write-Section "WinGet Result"

Write-InfoLine "Already present" $Present.ToString()
Write-InfoLine $(if ($DryRun) { "Would install" } else { "Newly installed" }) $Installed.ToString()
Write-InfoLine "Optional failures" $OptionalFailures.ToString()
Write-InfoLine "Deferred downloads" $DeferredFailures.ToString()
Write-InfoLine "Required failures" $RequiredFailures.ToString()

Add-ReportLine ""
Add-ReportLine "Already present: $Present"
Add-ReportLine "Newly installed: $Installed"
Add-ReportLine "Optional failures: $OptionalFailures"
Add-ReportLine "Deferred downloads: $DeferredFailures"
Add-ReportLine "Required failures: $RequiredFailures"

if ($DeferredStatePath -and -not $DryRun) {
    @($DeferredPackageIds) |
        ConvertTo-Json |
        Set-Content -LiteralPath $DeferredStatePath -Encoding UTF8
}

if ($RequiredFailures -eq 0 -and $DeferredFailures -eq 0) {
    Write-OK "Overall status" "PASS"
    Add-ReportLine "Overall status: PASS"
}
elseif ($RequiredFailures -eq 0) {
    Write-Warn "Overall status" `
        "DEFERRED - rerun bootstrap to retry required downloads"
    Add-ReportLine "Overall status: DEFERRED"
}
else {
    Write-Fail "Overall status" "INCOMPLETE"
    Add-ReportLine "Overall status: INCOMPLETE"
}

if ($Report) { Write-InfoLine "Report" $Report } else { Write-InfoLine "Report" "suppressed in dry-run mode" }
Add-ReportLine "Report: $Report"

if ($RequiredFailures -gt 0) {
    exit 1
}

exit 0

