# Windows Bootstrap

Recreates Matthew's lean, remote-first Windows environment.

## Design goals

- PowerShell 7 launched directly through Larry PowerShell
- WinGet for desktop applications
- Scoop for lightweight command-line tools
- Inventory before making changes
- Skip applications that are already installed
- Firefox as primary browser
- Chromium as secondary browser
- Cross-platform application consistency
- Thin-client use: remote access, SSH, web tools, and homelab administration

## Planned standard applications

- PowerShell 7
- Firefox
- Chromium
- Visual Studio Code
- Notepad++
- 1Password
- Spotify
- VLC
- FileZilla
- Moonlight
- Private Internet Access
- 7-Zip
- PowerToys

## Usage

Run the complete standard bootstrap from PowerShell 7:

```powershell
.\bootstrap.ps1 -Profile standard
```

Run the read-only system checks without reinstalling or reconfiguring anything:

```powershell
.\bootstrap.ps1 -Profile standard -VerifyOnly
```

Each module writes a timestamped report under `reports/`. Modules are run in
separate PowerShell processes so that each module's exit code cleanly stops the
pipeline on failure.

## Lightweight editors

- Windows: Notepad++
- macOS: CotEditor
- Linux: Geany
