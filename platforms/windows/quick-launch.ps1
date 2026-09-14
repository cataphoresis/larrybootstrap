# Apply the current user's taskbar policy; sign out and back in afterward.
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:LOCALAPPDATA 'LarryBootstrap\Taskbar'
$shell = New-Object -ComObject WScript.Shell
$menus = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
)
$links = @(Get-ChildItem $menus -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue)
# Windows PowerShell exposes the native StartApps module on Windows 10;
# PowerShell 7 cannot load every Windows app-management module directly.
$startAppsJson = & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command 'Get-StartApps | ConvertTo-Json -Compress'
if ($LASTEXITCODE -ne 0) { throw 'Could not enumerate current-user Start apps.' }
$startApps = @($startAppsJson | ConvertFrom-Json)
$names = @('Firefox', 'Visual Studio Code', 'PowerShell 7*', 'Notepad++',
    'File Explorer', 'FileZilla*', '1Password', 'Spotify', 'Balatro')
$resolved = @()
foreach ($name in $names) {
    if ($name -eq 'File Explorer') {
        $resolved += @{ Name = $name; Target = "$env:WINDIR\explorer.exe"; Arguments = '' }
    } elseif ($name -eq 'Balatro') {
        $steam = Get-ItemPropertyValue 'HKCU:\Software\Valve\Steam' -Name SteamExe
        if (-not (Test-Path -LiteralPath $steam)) { throw 'Steam executable is unavailable.' }
        $resolved += @{ Name = $name; Target = $steam; Arguments = '-applaunch 2379780' }
    } else {
        $link = $links | Where-Object { $_.BaseName -like $name -and $_.BaseName -notmatch 'ISE|Safe|Uninstall' } | Select-Object -First 1
        if ($name -eq 'PowerShell 7*') {
            $larryLink = $links | Where-Object BaseName -eq 'Larry PowerShell' | Select-Object -First 1
            if ($larryLink) { $link = $larryLink }
        }
        if ($link) {
            $target = $shell.CreateShortcut($link.FullName).TargetPath
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Broken Start menu shortcut: $($link.FullName)" }
            $resolved += @{ Name = $link.BaseName; Source = $link.FullName }
        } else {
            $packagedApps = @($startApps | Where-Object { $_.Name -like $name -and $_.AppID -like '*!*' })
            if ($packagedApps.Count -ne 1) { throw "Expected one Start app or shortcut for $name; found $($packagedApps.Count) packaged apps." }
            $resolved += @{ Name = $packagedApps[0].Name; AppUserModelID = $packagedApps[0].AppID }
        }
    }
}
if (-not $PSCmdlet.ShouldProcess('Current user taskbar', 'Back up and apply ordered launcher policy')) { return }
New-Item -ItemType Directory -Path $root -Force | Out-Null
$policy = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (Test-Path $policy) {
    Get-ItemProperty $policy | Export-Clixml (Join-Path $root "policy-$stamp.xml")
}
$layout = Join-Path $root 'TaskbarLayout.xml'
if (Test-Path $layout) { Copy-Item $layout "$layout.$stamp.bak" }
$pins = @()
foreach ($app in $resolved) {
    if ($app.AppUserModelID) {
        $escaped = [System.Security.SecurityElement]::Escape($app.AppUserModelID)
        $pins += "<taskbar:UWA AppUserModelID=`"$escaped`" />"
        continue
    }
    $path = Join-Path $root "$($app.Name).lnk"
    if ($app.Source) { Copy-Item -LiteralPath $app.Source -Destination $path -Force }
    else {
        $shortcut = $shell.CreateShortcut($path)
        $shortcut.TargetPath = $app.Target
        $shortcut.Arguments = $app.Arguments
        $shortcut.Save()
    }
    $escaped = [System.Security.SecurityElement]::Escape($path)
    $pins += "<taskbar:DesktopApp DesktopApplicationLinkPath=`"$escaped`" />"
}
@"
<LayoutModificationTemplate xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" Version="1">
  <CustomTaskbarLayoutCollection PinListPlacement="Replace">
    <defaultlayout:TaskbarLayout><taskbar:TaskbarPinList>
      $($pins -join "`n      ")
    </taskbar:TaskbarPinList></defaultlayout:TaskbarLayout>
  </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@ | Set-Content -LiteralPath $layout -Encoding UTF8
New-Item -Path $policy -Force | Out-Null
New-ItemProperty -Path $policy -Name StartLayoutFile -Value $layout -PropertyType String -Force | Out-Null
New-ItemProperty -Path $policy -Name LockedStartLayout -Value 1 -PropertyType DWord -Force | Out-Null
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name TaskbarSmallIcons -Value 0
Write-Host 'Taskbar policy prepared. Sign out and back in to apply; native validation is required.'
