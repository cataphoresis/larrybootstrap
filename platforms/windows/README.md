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

Parsec is retired from the Larry ecosystem. The cleanup stage removes the
Parsec app, its separately registered virtual display/USB drivers, and known
Parsec data only after the registered uninstallers have completed. Removal
requires an elevated PowerShell session.

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

Preview the complete reconciliation without making any persistent machine-state
changes:

```powershell
.\bootstrap.ps1 -Profile standard -DryRun
```

Dry-run mode performs inspection and prints planned actions to stdout. It does
not install or remove packages, refresh package sources, download files, create
temporary files, write reports or backups, change registry or configuration
values, restart processes, or prune old artifacts.

## Terminal presentation contract

LarryBootstrap output is bounded to 72 columns. Section borders, wrapped text,
and the right-side `[ OK ]`, `[WARN]`, `[FAIL]`, and `[INFO]` status column all
remain within that width. Seventy-two columns is the cross-platform design
standard: it fits conventional 80-column terminals while leaving enough room
for Windows paths. Redirected output follows the same width contract.

## Cross-OS filesystem safety

The standard profile keeps Windows Fast Startup disabled so Windows performs a
full shutdown before another operating system accesses shared NTFS volumes.
Hibernation is reported separately and is not disabled automatically; when it
is available, perform a full shutdown before switching operating systems.

For ext4, the supported Windows route is WSL 2 `wsl --mount` on Windows 11 or
the Microsoft Store version of WSL. It requires elevation, attaches an entire
offline disk, cannot attach the active Windows disk, and does not directly
support common USB flash-drive or SD-card readers. Generic `ro` is not accepted
by `wsl --mount`; advanced read-only use requires `--bare` followed by a
read-only mount inside Linux.

Windows has no Microsoft-supplied APFS filesystem driver. The bootstrap does
not install third-party APFS drivers automatically. Prefer macOS file sharing,
an exFAT exchange volume, or network transfer; evaluate any read-only
third-party driver manually before trusting important data to it.

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
