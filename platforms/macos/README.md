# MacBook Bootstrap

Recreates the preferred macOS environment for this MacBook.

## Goals

- Install Homebrew and command-line tools
- Install preferred applications
- Apply Finder, Dock, keyboard, trackpad, and power settings
- Preserve and install ChatGPT-Left75
- Produce verification and inventory reports
- Remain safe to run repeatedly

## Browser standard

- Firefox is the managed primary browser.
- Safari is the built-in secondary browser.
- Chrome and Chromium are intentionally not installed by this bootstrap.

## Standard profile

Homebrew manages:

- Firefox
- 1Password
- Spotify
- VLC
- Visual Studio Code
- Moonlight
- Rectangle
- Keka
- Stats

Amphetamine remains a manual/App Store item. FileZilla is handled by a separate
Intel-compatibility module using a reviewed local archive. Existing Wireshark,
Raspberry Pi Imager, Balena Etcher, Private Internet Access, HandBrake,
MKVToolNix, MakeMKV, and ChatGPT-Left75 installations are preserved and
verified where the implementation defines a check; they are not all installed
by the standard Homebrew profile.

## Command-line tools

- git
- ffmpeg
- yt-dlp
- wget
- jq
- gh

## Developer profile

The developer profile extends standard with Python, CMake, pkg-config, Node,
Wireshark, Balena Etcher, Private Internet Access, HandBrake, Raspberry Pi
Imager, Rust, and Tauri. Node uses the compatibility-managed official Intel
binary rather than Homebrew on this Monterey host.

## Custom application

- ChatGPT-Left75

## Usage

```bash
./bootstrap.sh --profile standard --dry-run
./bootstrap.sh --profile standard --verify-only
./bootstrap.sh --profile standard
./bootstrap.sh --profile developer --verify-only
```

The unified implementation has passed native Monterey dry-run, reconciliation,
idempotency, verification, syntax, ShellCheck, and 72-column presentation
validation. Runtime artifacts remain under ignored `reports/` and `backups/`
locations.

The standard-profile validation above was originally based on standalone
commit `a75d2cc`. Developer-profile source from standalone commit `732e6ce` is
synchronized exactly into the unified tree. The unified developer profile has
now passed native Monterey dry-run, profile-aware preflight verification, full
reconciliation, second-run idempotency, final verification, static checks, and
72-column presentation validation. The standalone repository remains the
unchanged recovery baseline.
