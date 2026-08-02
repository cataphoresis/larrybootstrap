param(
    [ValidateSet("Menu", "Install", "Verify", "Audit", "Reports", "Exit")]
    [string]$Action = "Menu",

    [ValidateSet("standard", "homelab", "developer")]
    [string]$Profile = "standard"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $IsWindows) {
    throw "launcher.ps1 is the Windows LarryLauncher. Use ./launcher.sh on macOS or Linux."
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Bootstrap = Join-Path $Root "bootstrap.ps1"
$Reports = Join-Path $Root "platforms\windows\reports"
$Pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source

function Show-LarryBanner {
    Write-Host ""
    Write-Host "             .-''''''''-." -ForegroundColor DarkGray
    Write-Host "          .-'  _      _  '-." -ForegroundColor DarkGray
    Write-Host "         /   .--.____.--.   \" -ForegroundColor DarkGray
    Write-Host "        |   / -  |  |  - \   |" -ForegroundColor DarkGray
    Write-Host "        |   | o  |__|  o |   |" -ForegroundColor DarkGray
    Write-Host "        |    \     _    /    |" -ForegroundColor DarkGray
    Write-Host "        |   .:'.  --  .':.   |" -ForegroundColor DarkGray
    Write-Host "         \  :.: '----' :.:  /" -ForegroundColor DarkGray
    Write-Host "          '._  ________  _.'       __" -ForegroundColor DarkGray
    Write-Host "              /|      |\        _/  \_" -ForegroundColor DarkGray
    Write-Host "         ____/ |______| \____  / PUSH \" -ForegroundColor DarkGray
    Write-Host "        /______/  ||  \______\ \______/" -ForegroundColor DarkGray
    Write-Host "                 _||_          /______\" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "+----------------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "|  L A R R Y L A U N C H E R  //  NODE ONLINE            |" -ForegroundColor Cyan
    Write-Host "+----------------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host ("|  SYSTEM  Windows            PROFILE  {0,-17}|" -f $Profile) -ForegroundColor DarkCyan
    Write-Host ("|  USER    {0,-19} HOST     {1,-17}|" -f $env:USERNAME, $env:COMPUTERNAME) -ForegroundColor DarkCyan
    Write-Host "+----------------------------------------------------------+" -ForegroundColor DarkCyan
}

function Invoke-ConnectionEffect {
    if ($env:LARRY_ANIMATE -ne "1" -or -not [Environment]::UserInteractive) {
        return
    }

    Write-Host "CONNECTING" -ForegroundColor DarkGray -NoNewline
    1..3 | ForEach-Object {
        Start-Sleep -Milliseconds 140
        Write-Host "." -ForegroundColor DarkGray -NoNewline
    }
    Write-Host " ONLINE" -ForegroundColor Green
}

function Invoke-Bootstrap {
    param([switch]$VerifyOnly)

    if (-not (Test-Path -LiteralPath $Bootstrap -PathType Leaf)) {
        throw "Bootstrap entry point not found: $Bootstrap"
    }

    $arguments = @("-Profile", $Profile)
    if ($VerifyOnly) {
        $arguments += "-VerifyOnly"
    }

    & $Pwsh -NoLogo -NoProfile -File $Bootstrap @arguments | Out-Host
    $exitCode = $LASTEXITCODE
    return $exitCode
}

function Show-Reports {
    Write-Host ""
    Write-Host "Recent Reports" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor DarkCyan

    if (-not (Test-Path -LiteralPath $Reports -PathType Container)) {
        Write-Host "[INFO] No report directory exists yet."
        return
    }

    $items = @(Get-ChildItem -LiteralPath $Reports -File |
        Where-Object Name -ne ".gitkeep" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 10)

    if ($items.Count -eq 0) {
        Write-Host "[INFO] No reports have been generated yet."
        return
    }

    foreach ($item in $items) {
        Write-Host ("[INFO] {0:yyyy-MM-dd HH:mm:ss}  {1}" -f $item.LastWriteTime, $item.Name)
    }

    Write-Host "[INFO] $Reports"
}

function Invoke-LarryAction {
    param([string]$SelectedAction)

    switch ($SelectedAction) {
        "Install" { return Invoke-Bootstrap }
        "Verify"  { return Invoke-Bootstrap -VerifyOnly }
        "Audit"   { return Invoke-Bootstrap -VerifyOnly }
        "Reports" { Show-Reports; return 0 }
        "Exit"    { return 0 }
        default    { throw "Unsupported action: $SelectedAction" }
    }
}

Show-LarryBanner
Invoke-ConnectionEffect

if ($Action -ne "Menu") {
    exit (Invoke-LarryAction -SelectedAction $Action)
}

while ($true) {
    Write-Host ""
    Write-Host "[1] Install / reconcile workstation"
    Write-Host "[2] Verify configuration"
    Write-Host "[3] Run system audit"
    Write-Host "[4] List recent reports"
    Write-Host "[Q] Disconnect"
    Write-Host ""

    $selection = (Read-Host "SELECT").Trim().ToUpperInvariant()
    $selectedAction = switch ($selection) {
        "1" { "Install" }
        "2" { "Verify" }
        "3" { "Audit" }
        "4" { "Reports" }
        "Q" { "Exit" }
        default { $null }
    }

    if (-not $selectedAction) {
        Write-Host "[WARN] Unknown selection." -ForegroundColor Yellow
        continue
    }

    if ($selectedAction -eq "Exit") {
        Write-Host "[INFO] Carrier dropped. Goodbye."
        exit 0
    }

    if ($selectedAction -eq "Install") {
        $confirmation = (Read-Host "Run the full bootstrap? [y/N]").Trim()
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "[INFO] Install cancelled."
            continue
        }
    }

    $code = Invoke-LarryAction -SelectedAction $selectedAction
    Write-Host "[INFO] Action finished with exit code $code."
}
