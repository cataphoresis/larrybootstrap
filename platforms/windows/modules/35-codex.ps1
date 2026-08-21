param([switch]$DryRun)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$ExtensionId = "openai.chatgpt"
$Report = New-TimestampedReport `
    -RootDirectory $Root `
    -Prefix "codex" `
    -DryRun:$DryRun
$Failures = 0

function Add-ReportLine {
    param([AllowEmptyString()][string]$Text)
    if ($Report) { $Text | Add-Content -Encoding UTF8 $Report }
}

function Record-CodexFailure {
    param([string]$Label, [string]$Message)
    $script:Failures++
    Write-Fail $Label $Message
    Add-ReportLine ("[FAIL] {0,-28} {1}" -f $Label, $Message)
}

function Get-CommandVersionLine {
    param([Parameter(Mandatory)][string]$CommandPath)

    return [string](& $CommandPath --version 2>$null |
        Select-Object -First 1)
}

function Test-CodexExtensionInstalled {
    param([Parameter(Mandatory)][string]$CodeCommand)

    $Extensions = @(& $CodeCommand --list-extensions 2>$null)
    return $Extensions -contains $ExtensionId
}

Write-Section "OpenAI Codex"
Add-ReportLine "Windows Bootstrap OpenAI Codex"
Add-ReportLine "=============================="
Add-ReportLine "Run date: $(Get-Date)"
Add-ReportLine ""

$NpmCommand = Get-NpmCommandPath
$CodexCommand = Get-CodexCommandPath

if ($DryRun) {
    if ($CodexCommand) {
        $Version = Get-CommandVersionLine -CommandPath $CodexCommand
        Write-OK "Codex CLI" $Version
        Add-ReportLine "[ OK ] Codex CLI $Version"
    }
    else {
        Write-InfoLine "Codex CLI" "would install after Node.js LTS"
        Add-ReportLine "[INFO] Codex CLI would install"
    }
}
elseif (-not $NpmCommand) {
    Record-CodexFailure "Codex CLI" "npm command unavailable"
}
else {
    Write-InfoLine "Codex CLI" "installing or updating..."
    & $NpmCommand install --global --no-audit --no-fund `
        "@openai/codex@latest" | Out-Host

    if ($LASTEXITCODE -ne 0) {
        Record-CodexFailure "Codex CLI" `
            "npm installation returned code $LASTEXITCODE"
    }
    else {
        $CodexCommand = Get-CodexCommandPath

        if ($CodexCommand) {
            $Version = Get-CommandVersionLine -CommandPath $CodexCommand
            Write-OK "Codex CLI" $Version
            Add-ReportLine "[ OK ] Codex CLI $Version"
        }
        else {
            Record-CodexFailure "Codex CLI" `
                "command unavailable after installation"
        }
    }
}

$CodeCommand = Get-VSCodeCommandPath

if ($DryRun) {
    if ($CodeCommand -and (Test-CodexExtensionInstalled $CodeCommand)) {
        Write-OK "Codex extension" $ExtensionId
        Add-ReportLine "[ OK ] Codex extension $ExtensionId"
    }
    else {
        Write-InfoLine "Codex extension" "would install after VS Code"
        Add-ReportLine "[INFO] Codex extension would install"
    }
}
elseif (-not $CodeCommand) {
    Record-CodexFailure "Codex extension" "VS Code command unavailable"
}
else {
    & $CodeCommand --install-extension $ExtensionId --force | Out-Host

    if (
        $LASTEXITCODE -eq 0 -and
        (Test-CodexExtensionInstalled $CodeCommand)
    ) {
        Write-OK "Codex extension" $ExtensionId
        Add-ReportLine "[ OK ] Codex extension $ExtensionId"
    }
    else {
        Record-CodexFailure "Codex extension" "installation failed"
    }
}

Write-InfoLine "First use" "sign in with ChatGPT"
Write-InfoLine "VS Code sidebar" `
    "Command Palette: Codex: Open Codex Sidebar"
Add-ReportLine "[INFO] First use: sign in with ChatGPT"
Add-ReportLine "[INFO] VS Code: Codex: Open Codex Sidebar"

if ($Failures -eq 0) {
    Write-OK "Overall status" "PASS"
    Add-ReportLine "Overall status: PASS"
}
else {
    Write-Fail "Overall status" "FAIL"
    Add-ReportLine "Overall status: FAIL"
}

if ($Report) {
    Write-InfoLine "Report" $Report
}
else {
    Write-InfoLine "Report" "suppressed in dry-run mode"
}

if ($Failures -gt 0) { exit 1 }
exit 0
