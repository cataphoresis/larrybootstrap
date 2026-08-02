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
```

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
