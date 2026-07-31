Set-StrictMode -Version Latest

function Write-Section {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host ""
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("=" * $Title.Length) -ForegroundColor DarkCyan
}

function Write-OK {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[ OK ] " -ForegroundColor Green -NoNewline
    Write-Host ("{0,-28} {1}" -f $Label, $Message)
}

function Write-Warn {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host ("{0,-28} {1}" -f $Label, $Message)
}

function Write-Fail {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[FAIL] " -ForegroundColor Red -NoNewline
    Write-Host ("{0,-28} {1}" -f $Label, $Message)
}

function Write-InfoLine {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
    Write-Host ("{0,-28} {1}" -f $Label, $Message)
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Test-CommandAvailable {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return $null -ne (
        Get-Command $Name -ErrorAction SilentlyContinue
    )
}

function Test-InternetConnection {
    param(
        [string]$HostName = "www.microsoft.com",
        [int]$Port = 443,
        [int]$TimeoutMilliseconds = 3000
    )

    try {
        $client = [System.Net.Sockets.TcpClient]::new()

        $task = $client.ConnectAsync($HostName, $Port)

        if (-not $task.Wait($TimeoutMilliseconds)) {
            $client.Dispose()
            return $false
        }

        $client.Dispose()
        return $true
    }
    catch {
        return $false
    }
}

function New-TimestampedReport {
    param(
        [Parameter(Mandatory)]
        [string]$RootDirectory,

        [Parameter(Mandatory)]
        [string]$Prefix
    )

    $reportDirectory = Join-Path $RootDirectory "reports"
    New-Item -ItemType Directory -Force $reportDirectory | Out-Null

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    return Join-Path `
        $reportDirectory `
        "$Prefix-$timestamp.txt"
}

function Test-ApplicationPath {
    param(
        [Parameter(Mandatory)]
        [string[]]$Paths
    )

    foreach ($path in $Paths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

function Get-WingetPackage {
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    if (-not (Test-CommandAvailable "winget")) {
        return $null
    }

    try {
        $output = winget list `
            --id $Id `
            --exact `
            --accept-source-agreements 2>$null

        if ($LASTEXITCODE -eq 0 -and $output -match [regex]::Escape($Id)) {
            return $output
        }
    }
    catch {
        return $null
    }

    return $null
}
