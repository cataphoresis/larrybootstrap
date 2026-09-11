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
        if (-not $link) { throw "Missing Start menu shortcut: $name. Install the app first." }
        $resolved += @{ Name = $link.BaseName; Source = $link.FullName }
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
