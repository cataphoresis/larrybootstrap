param(
    [ValidateSet("standard")]
    [string]$Profile = "standard",

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\lib\Common.ps1"

$ManifestPath = Join-Path $Root "profiles\direct-installs-$Profile.json"
$Report = New-TimestampedReport -RootDirectory $Root -Prefix "direct-installs" -DryRun:$DryRun
$Present = 0
$Installed = 0
$RequiredFailures = 0
$OptionalFailures = 0

function Add-ReportLine {
    param([AllowEmptyString()][string]$Text)
    if ($Report) { $Text | Add-Content -Encoding UTF8 $Report }
}

function Get-ExpandedDetectionPath {
    param([Parameter(Mandatory)][string]$Path)

    $Expanded = [Environment]::ExpandEnvironmentVariables($Path)

    if ($Expanded -match '%[^%]+%') {
        return $null
    }

    return $Expanded
}

function Find-InstalledApplication {
    param([Parameter(Mandatory)][pscustomobject]$Package)

    foreach ($Candidate in $Package.detectionPaths) {
        $Path = Get-ExpandedDetectionPath -Path ([string]$Candidate)

        if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return $Path
        }
    }

    return $null
}

function Test-AllowedDownloadHost {
    param(
        [Parameter(Mandatory)][uri]$Uri,
        [Parameter(Mandatory)][string[]]$Patterns
    )

    if ($Uri.Scheme -ne "https") { return $false }

    foreach ($Pattern in $Patterns) {
        if ($Uri.DnsSafeHost -like $Pattern) { return $true }
    }

    return $false
}

function Resolve-DirectDownloadUri {
    param([Parameter(Mandatory)][pscustomobject]$Package)

    $RequestedUri = [uri][string]$Package.downloadUri
    $AllowedHosts = @($Package.allowedDownloadHosts)

    if (-not (Test-AllowedDownloadHost -Uri $RequestedUri -Patterns $AllowedHosts)) {
        throw "Download URI is not an allowed HTTPS host: $RequestedUri"
    }

    $Response = Invoke-WebRequest -Uri $RequestedUri -Method Head -MaximumRedirection 10 -UseBasicParsing
    $ResolvedUri = $Response.BaseResponse.RequestMessage.RequestUri

    if (-not (Test-AllowedDownloadHost -Uri $ResolvedUri -Patterns $AllowedHosts)) {
        throw "Download redirected to an unapproved host: $($ResolvedUri.DnsSafeHost)"
    }

    return $ResolvedUri
}

function Install-DirectPackage {
    param([Parameter(Mandatory)][pscustomobject]$Package)

    $DownloadUri = Resolve-DirectDownloadUri -Package $Package

    $TemporaryPath = Join-Path ([IO.Path]::GetTempPath()) ("larry-bootstrap-{0}.exe" -f [guid]::NewGuid())

    try {
        Write-InfoLine $Package.name "downloading from $($DownloadUri.DnsSafeHost)"
        Invoke-WebRequest -Uri $DownloadUri -OutFile $TemporaryPath -UseBasicParsing

        $Header = [byte[]]::new(2)
        $Stream = [IO.File]::OpenRead($TemporaryPath)

        try {
            [void]$Stream.Read($Header, 0, $Header.Length)
        }
        finally {
            $Stream.Dispose()
        }

        if ($Header[0] -ne 0x4D -or $Header[1] -ne 0x5A) {
            throw "Download source returned a web page instead of a Windows installer"
        }

        $Signature = Get-AuthenticodeSignature -FilePath $TemporaryPath

        if ($Signature.Status -ne "Valid") {
            throw "Installer signature is $($Signature.Status), expected Valid"
        }

        $Signer = $Signature.SignerCertificate.Subject

        if ($Signer -notmatch [string]$Package.publisherPattern) {
            throw "Unexpected installer signer: $Signer"
        }

        Write-OK "$($Package.name) signature" $Signer
        Add-ReportLine ("[ OK ] {0,-28} signed by {1}" -f "$($Package.name) signature", $Signer)

        $Process = Start-Process -FilePath $TemporaryPath -ArgumentList @($Package.silentArguments) -Wait -PassThru

        if ($Process.ExitCode -notin @(0, 3010)) {
            throw "Installer exited with code $($Process.ExitCode)"
        }

        $InstalledPath = Find-InstalledApplication -Package $Package

        if (-not $InstalledPath) {
            throw "Installer completed but the application was not detected"
        }

        return $InstalledPath
    }
    finally {
        Remove-Item -LiteralPath $TemporaryPath -Force -ErrorAction SilentlyContinue
    }
}

Add-ReportLine "Windows Bootstrap Direct Installation"
Add-ReportLine "====================================="
Add-ReportLine "Run date: $(Get-Date)"
Add-ReportLine "Profile: $Profile"
Add-ReportLine "Manifest: $ManifestPath"
Add-ReportLine ""

Write-Section "Direct Application Installation"
Write-InfoLine "Profile" $Profile
Write-InfoLine "Manifest" $ManifestPath

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    Write-Fail "Manifest" "not found: $ManifestPath"
    Add-ReportLine "[FAIL] Manifest not found"
    exit 1
}

$Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$Packages = @($Manifest.packages)
Write-OK "Manifest entries" $Packages.Count.ToString()
Add-ReportLine "Manifest entries: $($Packages.Count)"

foreach ($Package in $Packages) {
    Write-Section ([string]$Package.name)
    $ExistingPath = Find-InstalledApplication -Package $Package

    if ($ExistingPath) {
        $Present++
        Write-OK $Package.name "already installed at $ExistingPath"
        Add-ReportLine ("[ OK ] {0,-28} already installed ({1})" -f $Package.name, $ExistingPath)
        continue
    }

    if ($DryRun) {
        $Installed++
        Write-InfoLine $Package.name "would download, validate, and install"
        Add-ReportLine ("[INFO] {0,-28} would install" -f $Package.name)
        continue
    }

    try {
        $InstalledPath = Install-DirectPackage -Package $Package
        $Installed++
        Write-OK $Package.name "installed at $InstalledPath"
        Add-ReportLine ("[ OK ] {0,-28} installed ({1})" -f $Package.name, $InstalledPath)
    }
    catch {
        if ([bool]$Package.required) {
            $RequiredFailures++
            Write-Fail $Package.name $_.Exception.Message
            Add-ReportLine ("[FAIL] {0,-28} {1}" -f $Package.name, $_.Exception.Message)
        }
        else {
            $OptionalFailures++
            $Message = $_.Exception.Message

            if ($Package.PSObject.Properties.Name -contains "manualDownloadUri") {
                $Message += "; install manually from $($Package.manualDownloadUri)"
            }

            Write-Warn $Package.name $Message
            Add-ReportLine ("[WARN] {0,-28} {1}" -f $Package.name, $Message)
        }
    }
}

Write-Section "Direct Installation Result"
Write-InfoLine "Already present" $Present.ToString()
Write-InfoLine $(if ($DryRun) { "Would install" } else { "Newly installed" }) $Installed.ToString()
Write-InfoLine "Optional failures" $OptionalFailures.ToString()
Write-InfoLine "Required failures" $RequiredFailures.ToString()

$Status = if ($RequiredFailures -eq 0) { "PASS" } else { "INCOMPLETE" }

if ($RequiredFailures -eq 0) {
    Write-OK "Overall status" $Status
}
else {
    Write-Fail "Overall status" $Status
}

if ($Report) { Write-InfoLine "Report" $Report } else { Write-InfoLine "Report" "suppressed in dry-run mode" }
Add-ReportLine ""
Add-ReportLine "Already present: $Present"
Add-ReportLine "Newly installed: $Installed"
Add-ReportLine "Optional failures: $OptionalFailures"
Add-ReportLine "Required failures: $RequiredFailures"
Add-ReportLine "Overall status: $Status"
Add-ReportLine "Report: $Report"

if ($RequiredFailures -gt 0) { exit 1 }
exit 0
