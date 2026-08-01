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

function Invoke-BootstrapArtifactRetention {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootDirectory,

        [ValidateRange(1, 100)]
        [int]$KeepPerModule = 3
    )

    $TimestampPattern =
        '^(?<Prefix>.+)-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$'

    foreach ($ArtifactDirectoryName in @("reports", "backups")) {
        $ArtifactDirectory = Join-Path $RootDirectory $ArtifactDirectoryName

        if (-not (Test-Path -LiteralPath $ArtifactDirectory -PathType Container)) {
            continue
        }

        $Artifacts = Get-ChildItem -LiteralPath $ArtifactDirectory -Force |
            Where-Object { $_.Name -ne ".gitkeep" } |
            ForEach-Object {
                $ComparableName = if ($_.PSIsContainer) {
                    $_.Name
                }
                else {
                    [IO.Path]::GetFileNameWithoutExtension($_.Name)
                }

                if ($ComparableName -match $TimestampPattern) {
                    [pscustomobject]@{
                        Artifact = $_
                        Prefix   = $Matches.Prefix
                    }
                }
            }

        foreach ($Group in $Artifacts | Group-Object Prefix) {
            $Group.Group |
                Sort-Object { $_.Artifact.LastWriteTimeUtc } -Descending |
                Select-Object -Skip $KeepPerModule |
                ForEach-Object {
                    Remove-Item -LiteralPath $_.Artifact.FullName -Recurse -Force
                }
        }
    }
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

function Get-PackageManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Package manifest not found: $Path"
    }

    $LineNumber = 0

    foreach ($Line in Get-Content -LiteralPath $Path) {
        $LineNumber++
        $TrimmedLine = $Line.Trim()

        # Ignore blank lines and comments.
        if (
            [string]::IsNullOrWhiteSpace($TrimmedLine) -or
            $TrimmedLine.StartsWith("#")
        ) {
            continue
        }

        $Fields = $TrimmedLine.Split("|")

        if ($Fields.Count -ne 3) {
            throw (
                "Invalid manifest entry at line ${LineNumber}: " +
                "expected id|display|required"
            )
        }

        $Id = $Fields[0].Trim()
        $DisplayName = $Fields[1].Trim()
        $RequiredText = $Fields[2].Trim()

        if ([string]::IsNullOrWhiteSpace($Id)) {
            throw "Missing package ID at line $LineNumber."
        }

        if ([string]::IsNullOrWhiteSpace($DisplayName)) {
            throw "Missing display name at line $LineNumber."
        }

        $Required = $false

        if (-not [bool]::TryParse($RequiredText, [ref]$Required)) {
            throw (
                "Invalid required value at line ${LineNumber}: " +
                "'$RequiredText' must be true or false."
            )
        }

        [pscustomobject]@{
            Id         = $Id
            DisplayName = $DisplayName
            Required   = $Required
            LineNumber = $LineNumber
        }
    }
}

function Test-WinGetPackageInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    try {
        $Output = winget list `
            --id $Id `
            --exact `
            --accept-source-agreements 2>$null

        return ($LASTEXITCODE -eq 0 -and $Output -match [regex]::Escape($Id))
    }
    catch {
        return $false
    }
}

function Install-WinGetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Package
    )

    if (Test-WinGetPackageInstalled $Package.Id) {

        Write-OK $Package.DisplayName "already installed"

        return $true
    }

    Write-InfoLine $Package.DisplayName "installing..."

    $Arguments = @(
        "install"
        "--id"
        $Package.Id
        "--exact"
        "--accept-package-agreements"
        "--accept-source-agreements"
    )

    & winget @Arguments | Out-Host
    $ExitCode = $LASTEXITCODE

    if ($ExitCode -eq 0) {

        Write-OK $Package.DisplayName "installed"

        return $true
    }

    if ($Package.Required) {

        Write-Fail $Package.DisplayName "installation failed"

    }
    else {

        Write-Warn $Package.DisplayName "optional package failed"

    }

    return $false
}

