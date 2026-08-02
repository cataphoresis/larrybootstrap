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

Firefox is managed as the primary browser. The browser module configures
automatic installation of uBlock Origin, SponsorBlock, EFF Privacy Badger, and
1Password through Mozilla enterprise policy. Windows may still require one
manual confirmation in Default apps to make Firefox the system default.

PowerToys FancyZones and Workspaces are enabled automatically. The initial
`Command`, `Browse`, and `Remote` workspace captures remain manual because they
depend on the final application positions and monitor arrangement.

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

After every run, the bootstrap retains the newest three reports and backup
sets for each module and removes older ones. This keeps troubleshooting history
without allowing repeated runs to consume space indefinitely.

## Lightweight editors

- Windows: Notepad++
- macOS: CotEditor
- Linux: Geany
