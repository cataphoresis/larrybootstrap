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

## Custom application

- ChatGPT-Left75

## Usage

```bash
./bootstrap.sh --profile standard --dry-run
./bootstrap.sh --profile standard --verify-only
./bootstrap.sh --profile standard
```

The unified implementation has passed native Monterey dry-run, reconciliation,
idempotency, verification, syntax, ShellCheck, and 72-column presentation
validation. Runtime artifacts remain under ignored `reports/` and `backups/`
locations.
