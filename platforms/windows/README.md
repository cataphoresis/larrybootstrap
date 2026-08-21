# Windows Bootstrap

Recreates Matthew's lean, remote-first Windows environment.

## Design goals

- PowerShell 7 launched directly through Larry PowerShell
- WinGet for desktop applications
- Inventory before making changes
- Skip applications that are already installed
- Firefox as primary browser
- Chromium as secondary browser
- Cross-platform application consistency
- Thin-client use: remote access, SSH, and web tools

## Implemented standard applications

- PowerShell 7
- Git
- GitHub CLI
- Firefox
- Chromium
- Visual Studio Code
- Node.js LTS and npm
- Codex CLI and the VS Code Codex extension
- Notepad++
- 1Password
- Spotify
- VLC
- FileZilla
- Moonlight
- Private Internet Access
- 7-Zip
- PowerToys

Stage 0 installs PowerShell 7 from the official PowerShell GitHub release when
needed, then uses Microsoft's WinGet repair module to establish a functional
App Installer. The Windows PowerShell Stage 0 process hands off to a new
elevated PowerShell 7 console and exits. Git and GitHub CLI are installed by
the standard WinGet stage when absent. Required package installs are retried
once after a transient failure, and the parent process refreshes PATH before
later configuration and verification stages.

The developer-tooling stage installs `@openai/codex` globally with npm and
installs the `openai.chatgpt` VS Code extension. Final verification requires
the `node`, `npm`, `codex`, and `code` commands plus that extension.

Inventory captures WinGet through a timeout-bounded native process. Native
stdout is never piped through PowerShell formatting or `Out-File`, avoiding a
known Windows 10 hang while still allowing inventory to continue on failure.

The elevated bootstrap remains the machine-level orchestrator. Packages marked
with `user` context in the manifest run through a temporary interactive task
with `RunLevel Limited`, so installers such as Spotify receive the logged-in
user's normal token. The helper refuses to invoke WinGet unless it verifies
that its own token is non-elevated.
Required downloads receive two delayed retries. DNS, network, and download
failures are reported as deferred with a rerun instruction, allowing remaining
configuration stages to finish. A per-run temporary state file lets final
verification keep those exact deferred package IDs as warnings; any other
missing required application remains a failure. VLC additionally retries from
Debian's VideoLAN mirror, dynamically selecting the current signed win64 MSI.

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

Windows supports the `standard` profile. The `homelab` profile remains
Linux-only.

Run the complete standard bootstrap from an elevated stock Windows PowerShell
prompt without changing persistent execution policy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File .\bootstrap.ps1 -Profile standard
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

If PowerShell 7 or WinGet is unavailable, dry-run reports which prerequisite
would be established and stops because the normal pipeline cannot yet run.

The known Windows 10 host validates at 36 passed checks, one understood warning
for a WSL build without `wsl --mount`, and zero failures. Exact clean-machine
validation remains a separate-machine/full-VM gate; Windows Sandbox is not a
representative target for AppX, user-context, or networking-driver installers.

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
