param([switch]$DryRun)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\Common.ps1"
Write-Section 'Authenticated SMB shares'
$Account = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$SharePath = $env:LARRY_SHARE_PATH
if (-not $SharePath) {
    $Volumes = @(Get-Volume | Where-Object { $_.FileSystemLabel -in @('LARRYSHARED', 'LARRYSHARE') -and $_.DriveLetter })
    if ($Volumes.Count -ne 1) { throw 'Mount LarryShare or set LARRY_SHARE_PATH to its drive root.' }
    $SharePath = "$($Volumes[0].DriveLetter):\"
}
if (-not (Test-Path -LiteralPath $SharePath -PathType Container)) { throw "Missing LarryShare volume: $SharePath" }
$Shares = @(
    @{ Name = 'OS'; Path = "$env:SystemDrive\"; Access = 'Read' },
    @{ Name = 'LarryShare'; Path = $SharePath; Access = 'Change' }
)
$State = Join-Path $env:ProgramData 'LarryBootstrap\SMB'
foreach ($Share in $Shares) {
    $Existing = Get-SmbShare -Name $Share.Name -ErrorAction SilentlyContinue
    $Marker = Join-Path $State "$($Share.Name).json"
    if ($Existing -and (-not (Test-Path $Marker) -or $Existing.Path -ne $Share.Path)) {
        throw "Unmanaged or conflicting share $($Share.Name); leaving it unchanged."
    }
    if ($DryRun) { Write-InfoLine $Share.Name "would share $($Share.Path): $($Share.Access) for $Account"; continue }
    New-Item -ItemType Directory -Path $State -Force | Out-Null
    if (-not $Existing) {
        $Arguments = @{ Name = $Share.Name; Path = $Share.Path; FolderEnumerationMode = 'AccessBased' }
        if ($Share.Access -eq 'Read') { $Arguments.ReadAccess = $Account } else { $Arguments.ChangeAccess = $Account }
        New-SmbShare @Arguments | Out-Null
        $Share | ConvertTo-Json | Set-Content -LiteralPath $Marker -Encoding UTF8
    } else {
        Get-SmbShareAccess -Name $Share.Name | Export-Clixml "$Marker.$(Get-Date -Format yyyyMMdd-HHmmss).bak"
        # Managed shares only: retain a single authenticated account permission.
        foreach ($Ace in Get-SmbShareAccess -Name $Share.Name) {
            if ($Ace.AccessControlType -eq 'Allow') {
                Revoke-SmbShareAccess -Name $Share.Name -AccountName $Ace.AccountName -Force | Out-Null
            }
        }
        Grant-SmbShareAccess -Name $Share.Name -AccountName $Account -AccessRight $Share.Access -Force | Out-Null
    }
}
if (-not $DryRun) {
    Set-Service LanmanServer -StartupType Automatic
    Start-Service LanmanServer
    if (-not (Get-NetFirewallRule -Name LarryBootstrap-SMB -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name LarryBootstrap-SMB -DisplayName 'LarryBootstrap SMB (private LAN)' `
            -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Profile Private -RemoteAddress LocalSubnet | Out-Null
    }
}
Write-InfoLine 'SMB authentication' "Use $Account and its Windows password, not the Windows Hello PIN."
Write-InfoLine 'Share access' 'OS read-only; LarryShare read/write. NTFS permissions remain effective. No guest grant.'
