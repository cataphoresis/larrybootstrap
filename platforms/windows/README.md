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

Windows APFS access uses optional `Paragon.APFS` from WinGet. This is a
commercial trial, not freeware: activate a license for continued use and choose
read-only access before browsing the Mac volume. DiskGenius is included for
advanced partition management; its free edition is not open source. Neither
tool is invoked to modify disks by the bootstrap.

Each module writes a timestamped report under `reports/`. Modules are run in
separate PowerShell processes so that each module's exit code cleanly stops the
pipeline on failure.

After every run, the bootstrap retains the newest three reports and backup
sets for each module and removes older ones. This keeps troubleshooting history
without allowing repeated runs to consume space indefinitely.

## Lightweight editors

- Windows: Notepad++
- macOS: CotEditor
- Linux: Mousepad

## Ordered bottom launchers

See the [shared launcher standard](../../README.md#bottom-launcher-standard)
for the focused setup command, prerequisites, backups, and platform behavior.

Run `./platforms/windows/quick-launch.ps1` from the repository root in an
Administrator PowerShell under the desktop user's account. `-WhatIf` resolves
all nine applications without writing settings. The script supports packaged
Start apps such as 1Password and prefers Larry PowerShell for the terminal pin.
The policy and ordered XML were verified natively on September 14; sign-out/in
and visual confirmation remain pending. Large taskbar buttons are enabled.
Windows display scaling controls their physical size; the Debian 72-pixel
panel and 60-pixel icons are not independent native Windows taskbar settings.

## September 14 Windows reconciliation

Full apply now requests Administrator elevation before running its modules;
dry-run and verification do not request elevation. The native full run passed
54 checks with one known WSL `--mount` warning and zero failures. The initial
unelevated run stopped at SMB creation, which the elevated rerun resolved.

FileZilla is required. The September 3 SourceForge download returned HTML and
was previously only an optional warning. If the automatic download is blocked,
save the official `FileZilla_*_win64-setup.exe` in the user's Downloads folder
and rerun. A local installer undergoes the same executable-header, valid
Authenticode signature, and FileZilla publisher checks as a download. The
installed FileZilla 3.71.1 and its shortcut now verify successfully.

The required Visual C++ v14 x64 runtime uses
`https://aka.ms/vs/17/release/vc_redist.x64.exe`, validates Microsoft's signature,
and installs silently with `/install /quiet /norestart` when absent. The x64
runtime registry entry is used for installation and verification detection.
The underscore spelling `vc_redist_x64.exe` redirects to Bing and is not an
installer URL. Existing runtime 14.51.36247 was retained on this workstation.

Direct installers wait for the installer process itself, with a ten-minute
timeout, so an application opened by an Electron installer does not block the
bootstrap until that application closes. Fresh-install validation of this
revised wait path remains pending; the installed-app rerun passed.

## Expanded workstation setup

The standard manifest includes FFmpeg, Python 3.13, DiskGenius and optional
Paragon APFS. Etcher resolves the latest `balena-io/etcher` GitHub release's
Windows Setup.exe, checks its SHA-256 when published and validates Authenticode
before installation. Missing/ambiguous assets or invalid signatures fail safely.

The current official ChatGPT desktop is Microsoft Store product `9PLM9XGG6VKS`,
installed with a non-elevated interactive-user task. It is not ChatGPT Classic.
The shared Firefox manifest enforces 1Password, uBlock Origin, SponsorBlock,
Privacy Badger and ChatGPT Export. Restart Firefox after applying policy.

The SMB stage creates authenticated `OS` (read-only) and `LarryShare` (read/write)
shares for the current account and adds a private-LAN TCP 445 firewall rule.
LarryShare is found by volume label LARRYSHARED/LARRYSHARE, or set
`LARRY_SHARE_PATH` explicitly. Existing unmanaged shares are not overwritten.
Use the Windows account password for SMB, not a Windows Hello PIN.
