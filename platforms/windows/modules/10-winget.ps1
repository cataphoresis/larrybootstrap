param(
    [ValidateSet("standard")]
    [string]$Profile = "standard"
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
    -Prefix "winget"

$Installed = 0
$Present = 0
$RequiredFailures = 0
$OptionalFailures = 0

function Add-ReportLine {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    $Text | Add-Content -Encoding UTF8 $Report
}

"Windows Bootstrap WinGet Installation" |
    Set-Content -Encoding UTF8 $Report

"=======================================" |
    Add-Content $Report

"Run date: $(Get-Date)" |
    Add-Content $Report

"Profile: $Profile" |
    Add-Content $Report

"Manifest: $ManifestPath" |
    Add-Content $Report

"" | Add-Content $Report

Write-Section "Windows Package Installation"

Write-InfoLine "Profile" $Profile
Write-InfoLine "Manifest" $ManifestPath
Write-InfoLine "Free space" (
    "{0:N1} GB" -f (
        (Get-Volume -DriveLetter $env:SystemDrive.TrimEnd(":")).SizeRemaining /
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

    $Result = Install-WinGetPackage -Package $Package

    if ($Result) {
        Add-ReportLine (
            "[ OK ] {0,-28} installed ({1})" -f
            $Package.DisplayName,
            $Package.Id
        )

        $Installed++
        continue
    }

    if ($Package.Required) {
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

Write-Section "Python Tooling"

$PythonExecutable = Get-ChildItem `
    -LiteralPath (Join-Path $env:LOCALAPPDATA "Programs\Python") `
    -Filter "python.exe" `
    -File `
    -Recurse `
    -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending |
    Select-Object -First 1

if (-not $PythonExecutable) {
    Write-Fail "Python tooling" "python.exe was not found after package installation"
    Add-ReportLine "[FAIL] Python tooling              python.exe was not found"
    $RequiredFailures++
}
else {
    & $PythonExecutable.FullName -m ensurepip --upgrade | Out-Host

    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Python pip" "ensurepip failed"
        Add-ReportLine "[FAIL] Python pip                  ensurepip failed"
        $RequiredFailures++
    }
    else {
        $PythonRoot = Split-Path -Parent $PythonExecutable.FullName
        $PythonScripts = Join-Path $PythonRoot "Scripts"
        $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $PathEntries = @($PythonRoot, $PythonScripts) + @(
            $UserPath -split ";" | Where-Object { $_ }
        )
        $UpdatedPath = ($PathEntries | Select-Object -Unique) -join ";"
        [Environment]::SetEnvironmentVariable("Path", $UpdatedPath, "User")

        $PipVersion = & $PythonExecutable.FullName -m pip --version
        Write-OK "Python tooling" $PipVersion
        Add-ReportLine "[ OK ] Python tooling              $PipVersion"
    }
}

Write-Section "WinGet Result"

Write-InfoLine "Already present" $Present.ToString()
Write-InfoLine "Newly installed" $Installed.ToString()
Write-InfoLine "Optional failures" $OptionalFailures.ToString()
Write-InfoLine "Required failures" $RequiredFailures.ToString()

Add-ReportLine ""
Add-ReportLine "Already present: $Present"
Add-ReportLine "Newly installed: $Installed"
Add-ReportLine "Optional failures: $OptionalFailures"
Add-ReportLine "Required failures: $RequiredFailures"

if ($RequiredFailures -eq 0) {
    Write-OK "Overall status" "PASS"
    Add-ReportLine "Overall status: PASS"
}
else {
    Write-Fail "Overall status" "INCOMPLETE"
    Add-ReportLine "Overall status: INCOMPLETE"
}

Write-InfoLine "Report" $Report
Add-ReportLine "Report: $Report"

if ($RequiredFailures -gt 0) {
    exit 1
}

exit 0

