param(
    [ValidateSet("standard")]
    [string]$Profile = "standard"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$PackageManifestPath = Join-Path $Root "profiles\packages-$Profile.txt"
$DirectManifestPath = Join-Path $Root "profiles\direct-installs-$Profile.json"
$PowerShellSchemaPath = Join-Path $Root "schema\powershell.json"
$Report = New-TimestampedReport -RootDirectory $Root -Prefix "verify"
$Failures = 0
$Warnings = 0
$Passed = 0

function Add-ReportLine {
    param([AllowEmptyString()][string]$Text)
    $Text | Add-Content -Encoding UTF8 $Report
}

function Record-OK {
    param([string]$Label, [string]$Message)
    $script:Passed++
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

function Test-RegistryValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object]$Expected,
        [Parameter(Mandatory)][string]$Label
    )

    try {
        $Actual = Get-ItemPropertyValue -LiteralPath $Path -Name $Name -ErrorAction Stop

        if ($Actual -eq $Expected) {
            Record-OK $Label "configured ($Actual)"
        }
        else {
            Record-Fail $Label "expected $Expected, found $Actual"
        }
    }
    catch {
        Record-Fail $Label "setting not found"
    }
}

function Find-DirectApplication {
    param([Parameter(Mandatory)][pscustomobject]$Package)

    foreach ($Candidate in $Package.detectionPaths) {
        $Path = [Environment]::ExpandEnvironmentVariables([string]$Candidate)

        if ($Path -notmatch '%[^%]+%' -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return $Path
        }
    }

    return $null
}

"Windows Bootstrap Verification" | Set-Content -Encoding UTF8 $Report
"==============================" | Add-Content $Report
"Run date: $(Get-Date)" | Add-Content $Report
"Profile: $Profile" | Add-Content $Report
"" | Add-Content $Report

Write-Section "Core Tools"

foreach ($Tool in @("pwsh", "git", "winget")) {
    $Command = Get-Command $Tool -ErrorAction SilentlyContinue

    if ($Command) {
        Record-OK $Tool $Command.Source
    }
    else {
        Record-Fail $Tool "command not found"
    }
}

Write-Section "WinGet Applications"

if (-not (Test-Path -LiteralPath $PackageManifestPath -PathType Leaf)) {
    Record-Fail "Package manifest" "not found: $PackageManifestPath"
}
elseif (-not (Test-CommandAvailable "winget")) {
    Record-Fail "Package inventory" "WinGet is unavailable"
}
else {
    foreach ($Package in Get-PackageManifest -Path $PackageManifestPath) {
        if (Test-WinGetPackageInstalled -Id $Package.Id) {
            Record-OK $Package.DisplayName $Package.Id
        }
        elseif ($Package.Required) {
            Record-Fail $Package.DisplayName "required package is not installed ($($Package.Id))"
        }
        else {
            Record-Warn $Package.DisplayName "optional package is not installed ($($Package.Id))"
        }
    }
}

Write-Section "Direct Applications"

if (-not (Test-Path -LiteralPath $DirectManifestPath -PathType Leaf)) {
    Record-Fail "Direct manifest" "not found: $DirectManifestPath"
}
else {
    $DirectManifest = Get-Content -LiteralPath $DirectManifestPath -Raw | ConvertFrom-Json

    foreach ($Package in @($DirectManifest.packages)) {
        $ApplicationPath = Find-DirectApplication -Package $Package

        if ($ApplicationPath) {
            Record-OK $Package.name $ApplicationPath
        }
        elseif ([bool]$Package.required) {
            Record-Fail $Package.name "required direct application is not installed"
        }
        else {
            Record-Warn $Package.name "optional direct application is not installed"
        }
    }
}

Write-Section "Windows Settings"

$ExplorerAdvanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$Explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"

Test-RegistryValue -Path $ExplorerAdvanced -Name "HideFileExt" -Expected 0 -Label "Show file extensions"
Test-RegistryValue -Path $ExplorerAdvanced -Name "Hidden" -Expected 1 -Label "Show hidden files"
Test-RegistryValue -Path $ExplorerAdvanced -Name "ShowSuperHidden" -Expected 0 -Label "Protected system files"
Test-RegistryValue -Path $ExplorerAdvanced -Name "LaunchTo" -Expected 1 -Label "Explorer opens to This PC"
Test-RegistryValue -Path $Explorer -Name "ShowRecent" -Expected 0 -Label "Recent files in Explorer"
Test-RegistryValue -Path $Explorer -Name "ShowFrequent" -Expected 0 -Label "Frequent folders"
Test-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Expected 1 -Label "Long file paths"

Write-Section "Larry PowerShell"

if (-not (Test-Path -LiteralPath $PowerShellSchemaPath -PathType Leaf)) {
    Record-Fail "PowerShell schema" "not found: $PowerShellSchemaPath"
}
else {
    $PowerShellSchema = Get-Content -LiteralPath $PowerShellSchemaPath -Raw | ConvertFrom-Json
    $PwshCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue

    if ($PwshCommand) {
        $ProfilePath = & $PwshCommand.Source -NoLogo -NoProfile -Command '$PROFILE.CurrentUserAllHosts'

        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ProfilePath)) {
            Record-Fail "PowerShell profile" "could not resolve the profile path"
        }
        elseif (-not (Test-Path -LiteralPath ([string]$ProfilePath) -PathType Leaf)) {
            Record-Fail "PowerShell profile" "not found: $ProfilePath"
        }
        else {
            $ProfileText = Get-Content -LiteralPath ([string]$ProfilePath) -Raw

            if ($ProfileText -match '(?m)^# BEGIN LARRY-BOOTSTRAP\r?$' -and $ProfileText -match '(?m)^# END LARRY-BOOTSTRAP\r?$') {
                Record-OK "PowerShell profile" ([string]$ProfilePath)
            }
            else {
                Record-Fail "PowerShell profile" "managed block is missing"
            }
        }

        $ShortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$($PowerShellSchema.name).lnk"

        if (Test-Path -LiteralPath $ShortcutPath -PathType Leaf) {
            Record-OK "Start-menu shortcut" $ShortcutPath
        }
        else {
            Record-Fail "Start-menu shortcut" "not found: $ShortcutPath"
        }
    }

    $ProjectsPath = Join-Path $HOME "Projects"

    if (Test-Path -LiteralPath $ProjectsPath -PathType Container) {
        Record-OK "Projects directory" $ProjectsPath
    }
    else {
        Record-Fail "Projects directory" "not found: $ProjectsPath"
    }

    foreach ($Name in @("EDITOR", "VISUAL")) {
        $Expected = if ($Name -eq "EDITOR") { [string]$PowerShellSchema.editor } else { [string]$PowerShellSchema.visualEditor }
        $Actual = [Environment]::GetEnvironmentVariable($Name, "User")

        if ($Actual -eq $Expected) {
            Record-OK $Name $Actual
        }
        else {
            Record-Fail $Name "expected $Expected, found $Actual"
        }
    }
}

Write-Section "Browser Configuration"

$BrowserSchemaPath = Join-Path $Root "schema\browser.json"
$FirefoxPath = Test-ApplicationPath -Paths @(
    "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
    "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
)

if (-not $FirefoxPath) {
    Record-Fail "Firefox policy" "Firefox executable not found"
}
elseif (-not (Test-Path -LiteralPath $BrowserSchemaPath -PathType Leaf)) {
    Record-Fail "Browser schema" "not found: $BrowserSchemaPath"
}
else {
    $PolicyPath = Join-Path (Split-Path -Parent $FirefoxPath) "distribution\policies.json"

    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) {
        Record-Fail "Firefox policy" "not found: $PolicyPath"
    }
    else {
        try {
            $BrowserSchema = Get-Content -LiteralPath $BrowserSchemaPath -Raw | ConvertFrom-Json
            $Policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
            $ConfiguredUrls = @($Policy.policies.Extensions.Install)
            $MissingExtensions = @(
                $BrowserSchema.firefoxExtensions |
                    Where-Object { $_.installUrl -notin $ConfiguredUrls }
            )

            if ($MissingExtensions.Count -eq 0) {
                Record-OK "Firefox extensions" "$($ConfiguredUrls.Count) managed installations"
            }
            else {
                Record-Fail "Firefox extensions" "missing policy entries: $($MissingExtensions.name -join ', ')"
            }
        }
        catch {
            Record-Fail "Firefox policy" $_.Exception.Message
        }
    }
}

$DefaultProgId = Get-ItemPropertyValue `
    -LiteralPath "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice" `
    -Name "ProgId" `
    -ErrorAction SilentlyContinue

if ($DefaultProgId -match '^FirefoxURL') {
    Record-OK "Default browser" "Firefox"
}
else {
    Record-Warn "Default browser" "Firefox is not the HTTPS default"
}

Write-Section "PowerToys Workspaces"

$PowerToysSettingsPath = Join-Path $env:LOCALAPPDATA "Microsoft\PowerToys\settings.json"
$WorkspaceSchemaPath = Join-Path $Root "schema\workspaces.json"
$WorkspaceExportPath = Join-Path $Root "profiles\powertoys"

if (-not (Test-Path -LiteralPath $PowerToysSettingsPath -PathType Leaf)) {
    Record-Fail "PowerToys settings" "not found: $PowerToysSettingsPath"
}
elseif (-not (Test-Path -LiteralPath $WorkspaceSchemaPath -PathType Leaf)) {
    Record-Fail "Workspace schema" "not found: $WorkspaceSchemaPath"
}
else {
    try {
        $PowerToysSettings = Get-Content -LiteralPath $PowerToysSettingsPath -Raw | ConvertFrom-Json
        $WorkspaceSchema = Get-Content -LiteralPath $WorkspaceSchemaPath -Raw | ConvertFrom-Json

        foreach ($Module in $WorkspaceSchema.requiredModules) {
            $Property = $PowerToysSettings.enabled.PSObject.Properties[[string]$Module]

            if ($Property -and $Property.Value -eq $true) {
                Record-OK "PowerToys $Module" "enabled"
            }
            else {
                Record-Fail "PowerToys $Module" "not enabled"
            }
        }
    }
    catch {
        Record-Fail "PowerToys settings" $_.Exception.Message
    }
}

if (Test-Path -LiteralPath $WorkspaceExportPath -PathType Container) {
    Record-OK "Workspace exports" $WorkspaceExportPath
}
else {
    Record-Fail "Workspace exports" "not found: $WorkspaceExportPath"
}

Write-Section "Verification Result"
Write-InfoLine "Passed" $Passed.ToString()
Write-InfoLine "Warnings" $Warnings.ToString()
Write-InfoLine "Failures" $Failures.ToString()

$Status = if ($Failures -eq 0) { "PASS" } else { "FAIL" }

if ($Failures -eq 0) {
    Write-OK "Overall status" $Status
}
else {
    Write-Fail "Overall status" $Status
}

Write-InfoLine "Report" $Report
Add-ReportLine ""
Add-ReportLine "Passed: $Passed"
Add-ReportLine "Warnings: $Warnings"
Add-ReportLine "Failures: $Failures"
Add-ReportLine "Overall status: $Status"
Add-ReportLine "Report: $Report"

if ($Failures -gt 0) { exit 1 }
exit 0
