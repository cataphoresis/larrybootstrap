# LarryBootstrap

LarryBootstrap recreates the same remote-first workstation experience across
Windows, Linux, and macOS. Platform implementations remain native to each
operating system while shared profiles describe portable workstation intent.

## Repository layout

```text
common/
  profiles/            Shared application and workstation intent
  platform-baselines.json  Golden standalone source revisions
platforms/
  windows/             PowerShell and WinGet implementation
  linux/               Bash, APT, and Flatpak implementation
  macos/               Bash and Homebrew implementation
bootstrap.ps1          Windows entry point
bootstrap.sh           macOS/Linux entry point
launcher.ps1           Interactive Windows LarryLauncher
launcher.sh            Interactive macOS/Linux LarryLauncher
```

## LarryLauncher

LarryLauncher is a thin BBS-inspired front end for the native bootstrap. It
does not duplicate installation logic. Its menu provides install, verify,
audit, and recent-report actions, then delegates to the platform entry point.

Verification checks the workstation against the selected bootstrap profile.
Audit is a separate read-only system-health snapshot covering system uptime,
storage, networking, services, recent event warnings, startup entries, pending
reboots, and Windows Security status.

Windows:

```powershell
.\launcher.ps1
.\launcher.ps1 -Action Verify -Profile standard
```

macOS or Linux:

```bash
./launcher.sh
./launcher.sh --action verify --profile standard
```

Selecting a full installation from the interactive menu requires confirmation.
Passing an explicit install action is intended for scripts and runs immediately.
Set `LARRY_ANIMATE=1` to enable the short connection effect in an interactive
terminal; redirected and unattended output remains delay-free.

## Usage

Windows, from PowerShell 7:

```powershell
.\bootstrap.ps1 -Profile standard
.\bootstrap.ps1 -Profile standard -VerifyOnly
.\bootstrap.ps1 -Profile standard -DryRun
```

macOS:

```bash
./bootstrap.sh --profile standard
./bootstrap.sh --profile standard --verify-only
```

Linux:

```bash
./bootstrap.sh full
./bootstrap.sh audit
```

The root launchers detect or enforce the current platform and delegate every
option to the corresponding native bootstrap. Platform-specific READMEs
document additional profiles, behavior, and recovery details.

Cross-platform application intent is reconciled deliberately after native
platform behavior is imported and verified. The revisions recorded in
`common/platform-baselines.json` are the source-of-truth checkpoints for this
integration milestone.

The shared standard profile reconciles Firefox, the platform-native secondary
browser, Visual Studio Code, a lightweight editor, 1Password, VLC, Spotify, an
archive utility, and Moonlight. Applications without a safe or useful
implementation on all three systems remain platform-specific.

## Terminal style

LarryBootstrap uses an intentionally retro BBS-inspired terminal style on all
three operating systems. Main commands open with an ASCII banner and consistent
profile, user, computer, system, shell, and start-time details. Status output
uses `[ OK ]`, `[WARN]`, `[FAIL]`, and `[INFO]` markers. The shared presentation
contract is 72 columns, including redirected output. Any future animation must
be lightweight, terminal-only, and automatically disabled for redirected
output, logs, and unattended runs.

## Browser standard

- Windows and Linux: Firefox primary, Chromium secondary.
- macOS: Firefox primary, built-in Safari secondary.

## History and releases

The Windows, Linux, and macOS repositories were imported with their original
commit histories intact. Native validation across Windows, Debian 13, and
macOS Monterey is recorded by `unified-v1.0.0`. Windows clean-provisioning
hardening is recorded by `windows-v1.0.1` at commit `bab829f`.

The original standalone repositories remain recovery sources until the unified
bootstrap also completes an exact full-profile test on a separate physical
machine or conventional VM. Windows Sandbox was evaluated and rejected for
this purpose because its Windows 10 image does not support the required AppX
and networking-driver installers reliably.

## Packaging releases

The current packaged release targets Windows and preserves the tested
`launcher.ps1` behavior. From PowerShell 7:

```powershell
.\scripts\package-windows.ps1 -Version 1.0.1
```

The command creates a versioned ZIP and SHA-256 checksum in `dist/`. The ZIP
contains only the shared profile and Windows runtime dependencies needed by the
launcher; it excludes the Linux and macOS implementations.

Current packaging state:

1. Windows `v1.0.1` — packaged and validated on the known Windows host.
2. Linux — native implementation validated; standalone launcher packaging is
   still future work.
3. macOS — native implementation validated; standalone launcher packaging is
   still future work.

The next release gate is an exact Windows standard-profile installation on a
separate physical machine or full VM, followed by idempotency and final
verification. Do not retire the standalone recovery repositories before that
gate passes.
