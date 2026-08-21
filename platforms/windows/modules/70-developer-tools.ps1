param([switch]$DryRun)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$Report = New-TimestampedReport `
    -RootDirectory $Root `
    -Prefix "developer-tools" `
    -DryRun:$DryRun
$Failures = 0
$Changes = 0

function Add-ReportLine {
    param([AllowEmptyString()][string]$Text)
    if ($Report) { $Text | Add-Content -Encoding UTF8 $Report }
}

function Record-OK {
    param([string]$Label, [string]$Message)
    Write-OK $Label $Message
    Add-ReportLine ("[ OK ] {0,-28} {1}" -f $Label, $Message)
}

function Record-Fail {
    param([string]$Label, [string]$Message)
    $script:Failures++
    Write-Fail $Label $Message
    Add-ReportLine ("[FAIL] {0,-28} {1}" -f $Label, $Message)
}

Add-ReportLine "Windows Developer Tooling"
Add-ReportLine "========================="
Add-ReportLine "Run date: $(Get-Date)"
Add-ReportLine ""

Write-Section "Node.js and npm"

$Node = Get-Command node.exe -ErrorAction SilentlyContinue
$Npm = Get-Command npm.cmd -ErrorAction SilentlyContinue

if ($DryRun) {
    if ($Node) { Record-OK "Node.js" (& $Node.Source --version) }
    else { Record-OK "Node.js" "would be supplied by the WinGet stage" }
    if ($Npm) { Record-OK "npm" (& $Npm.Source --version) }
    else { Record-OK "npm" "would be supplied by the Node.js package" }
}
elseif (-not $Node -or -not $Npm) {
    Record-Fail "Node.js/npm" "commands are unavailable after package installation"
}
else {
    Record-OK "Node.js" (& $Node.Source --version)
    Record-OK "npm" (& $Npm.Source --version)
}

Write-Section "Codex CLI"

$Codex = Get-Command codex.cmd -ErrorAction SilentlyContinue
if ($Codex) {
    Record-OK "Codex CLI" (& $Codex.Source --version)
}
elseif ($DryRun) {
    Record-OK "Codex CLI" "would install globally from @openai/codex"
}
elseif ($Npm) {
    & $Npm.Source install --global "@openai/codex"
    if ($LASTEXITCODE -ne 0) {
        Record-Fail "Codex CLI" "npm installation failed with exit code $LASTEXITCODE"
    }
    else {
        $Changes++
        $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $env:Path = "$MachinePath;$UserPath"
        $Codex = Get-Command codex.cmd -ErrorAction SilentlyContinue
        if ($Codex) { Record-OK "Codex CLI" (& $Codex.Source --version) }
        else { Record-Fail "Codex CLI" "installed but command is not discoverable" }
    }
}

Write-Section "VS Code Codex Extension"

$Code = Get-Command code.cmd -ErrorAction SilentlyContinue
if (-not $Code) {
    if ($DryRun) { Record-OK "VS Code" "would be supplied by the WinGet stage" }
    else { Record-Fail "VS Code" "code.cmd is unavailable after package installation" }
}
else {
    $Extensions = @(& $Code.Source --list-extensions 2>$null)
    if ($Extensions -contains "openai.chatgpt") {
        Record-OK "Codex extension" "openai.chatgpt"
    }
    elseif ($DryRun) {
        Record-OK "Codex extension" "would install openai.chatgpt"
    }
    else {
        & $Code.Source --install-extension "openai.chatgpt" --force
        if ($LASTEXITCODE -ne 0) {
            Record-Fail "Codex extension" "installation failed with exit code $LASTEXITCODE"
        }
        else {
            $Changes++
            Record-OK "Codex extension" "openai.chatgpt installed"
        }
    }
}

Write-Section "Developer Tooling Result"
Write-InfoLine "Changes applied" $Changes.ToString()
Write-InfoLine "Failures" $Failures.ToString()
$Status = if ($Failures -eq 0) { "PASS" } else { "FAIL" }
if ($Failures -eq 0) { Write-OK "Overall status" $Status }
else { Write-Fail "Overall status" $Status }
if ($Report) { Write-InfoLine "Report" $Report }
else { Write-InfoLine "Report" "suppressed in dry-run mode" }

if ($Failures -gt 0) { exit 1 }
exit 0
