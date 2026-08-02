# LarryBootstrap

LarryBootstrap recreates the same remote-first workstation experience across
Windows, Linux, and macOS. Platform implementations remain native to each
operating system while shared profiles describe portable workstation intent.

## Repository layout

```text
common/
  profiles/            Shared application and workstation intent
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
Its home screen carries the original minimalist Larry ASCII mark: a tired,
bespectacled operator reluctantly pressing the button, distinct from any
existing game character.

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

The root launchers detect or enforce the current platform and delegate to the
corresponding native bootstrap. Platform-specific READMEs document additional
profiles, behavior, and recovery details.

Python is a baseline tool on every platform. Windows installs Python 3.13 and
verifies pip through `python -m pip`; Debian/Linux installs `python3`,
`python3-pip`, `python3-venv`, and `pipx`; macOS installs Homebrew Python and
verifies pip through `python3 -m pip`. Project dependencies should use a virtual
environment instead of modifying the operating system's Python environment.

## Terminal style

LarryBootstrap uses an intentionally retro BBS-inspired terminal style on all
three operating systems. Main commands open with an ASCII banner and consistent
profile, user, computer, system, shell, and start-time details. Status output
uses `[ OK ]`, `[WARN]`, `[FAIL]`, and `[INFO]` markers. Any future animation
must be lightweight, terminal-only, and automatically disabled for redirected
output, logs, and unattended runs.

## Browser standard

- Windows and Linux: Firefox primary, Chromium secondary.
- macOS: Firefox primary, built-in Safari secondary.

## History and releases

The Windows, Linux, and macOS repositories were imported with their original
commit histories intact. Platform releases use prefixed tags, including
`windows-v1.0.0` and `macos-v1.0.0`.

The original standalone repositories remain recovery sources until the unified
bootstrap has been validated on all three operating systems.

## Packaging releases

The initial packaged release targets Windows and preserves the tested
`launcher.ps1` behavior. From PowerShell 7:

```powershell
.\scripts\package-windows.ps1 -Version 0.1.0
```

The command creates a versioned ZIP and SHA-256 checksum in `dist/`. The ZIP
contains only the shared profile and Windows runtime dependencies needed by the
launcher; it excludes the Linux and macOS implementations.

Incremental launcher packaging follows this order:

1. Windows v0.1.x — establish the package and release process.
2. Linux v0.2.x — add a Linux-native launcher package and tests.
3. macOS v0.3.x — add a macOS-native launcher package and tests.
