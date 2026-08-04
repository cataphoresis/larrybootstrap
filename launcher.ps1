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

function Get-PrimaryIPv4Address {
    try {
        $configuration = Get-NetIPConfiguration -ErrorAction Stop |
            Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address } |
            Select-Object -First 1
        if ($configuration) {
            return $configuration.IPv4Address.IPAddress
        }
    }
    catch {
        # Fall back to DNS-based discovery on systems without NetTCPIP access.
    }

    try {
        $address = [Net.Dns]::GetHostAddresses([Net.Dns]::GetHostName()) |
            Where-Object {
                $_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork -and
                -not [Net.IPAddress]::IsLoopback($_)
            } |
            Select-Object -First 1
        if ($address) {
            return $address.IPAddressToString
        }
    }
    catch {
        # The banner remains usable when the machine is offline.
    }

    return "Unavailable"
}

function Get-SystemDriveFreeSpace {
    try {
        $driveName = $env:SystemDrive.TrimEnd('\').TrimEnd(':')
        $drive = Get-PSDrive -Name $driveName -PSProvider FileSystem -ErrorAction Stop
        return ("{0:N1} GB free" -f ($drive.Free / 1GB))
    }
    catch {
        return "Unavailable"
    }
}

function Limit-PanelValue {
    param(
        [string]$Value,
        [int]$MaximumLength
    )

    if ($Value.Length -le $MaximumLength) {
        return $Value
    }

    return $Value.Substring(0, $MaximumLength - 3) + "..."
}

function Show-LarryBanner {
    $ipAddress = Limit-PanelValue -Value (Get-PrimaryIPv4Address) -MaximumLength 19
    $diskFree = Limit-PanelValue -Value (Get-SystemDriveFreeSpace) -MaximumLength 17

    Write-Host ""
    Write-Host "+----------------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "|  L A R R Y L A U N C H E R  //  NODE ONLINE            |" -ForegroundColor Cyan
    Write-Host "+----------------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host ("|  SYSTEM  Windows            PROFILE  {0,-17}|" -f $Profile) -ForegroundColor DarkCyan
    Write-Host ("|  USER    {0,-19} HOST     {1,-17}|" -f $env:USERNAME, $env:COMPUTERNAME) -ForegroundColor DarkCyan
    Write-Host ("|  IP      {0,-19} DISK     {1,-17}|" -f $ipAddress, $diskFree) -ForegroundColor DarkCyan
    Write-Host "+----------------------------------------------------------+" -ForegroundColor DarkCyan
}

function Invoke-ConnectionEffect {
    if ($env:LARRY_ANIMATE -ne "1" -or -not [Environment]::UserInteractive) {
        return
    }

    foreach ($Stage in @("DIALING NODE", "NEGOTIATING 9600 BAUD", "AUTHENTICATING OPERATOR")) {
        Write-Host ("{0,-28}" -f $Stage) -ForegroundColor DarkGray -NoNewline
        1..3 | ForEach-Object {
            Start-Sleep -Milliseconds 220
            Write-Host "." -ForegroundColor DarkGray -NoNewline
        }
        Write-Host " OK" -ForegroundColor Green
    }
    Write-Host "CARRIER DETECTED // LARRYLINK ONLINE" -ForegroundColor Cyan
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
