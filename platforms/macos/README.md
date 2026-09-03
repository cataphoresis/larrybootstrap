# MacBook Bootstrap

Recreates the preferred macOS environment for this MacBook.

## Goals

- Install Homebrew and command-line tools
- Install preferred applications
- Apply Finder, Dock, keyboard, trackpad, and power settings
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
MKVToolNix and MakeMKV installations are preserved and
verified where the implementation defines a check; they are not all installed
by the standard Homebrew profile.

## Command-line tools

- git
- ffmpeg
- yt-dlp
- wget
- jq
- gh

## Monterey binary-install policy

The bootstrap does not knowingly compile Homebrew formulae from source on
Monterey. Before installing a formula, it checks the requested formula and its
missing dependencies for compatible precompiled bottles. If any bottle is
unavailable, the formula is skipped with a warning and an action to use a
reviewed official Intel package or manage the tool manually.

The preferred order is an already-compatible command, a compatible Homebrew
bottle, an official precompiled Intel package with integrity and architecture
checks, and finally an explicitly approved source build. Existing formulae are
not reinstalled merely because an older run compiled them from source.

## Developer profile

The developer profile extends standard with Python, CMake, pkg-config, Node,
Wireshark, Balena Etcher, Private Internet Access, HandBrake, Raspberry Pi
Imager, Rust, Tauri, the OpenAI VS Code extension, and Codex CLI. Node uses the
compatibility-managed official Intel binary rather than Homebrew on this
Monterey host. Codex is installed through npm after Node is available.

The two protected accessibility preferences are attempted normally. When
Monterey blocks them, the defaults module continues and reports that Terminal
needs Full Disk Access under System Preferences -> Security & Privacy ->
Privacy -> Full Disk Access. Verification reports inaccessible protected
preferences as warnings while still treating readable incorrect values as
failures.

## Usage

```bash
./bootstrap.sh --profile standard --dry-run
./bootstrap.sh --profile standard --verify-only
./bootstrap.sh --profile standard
./bootstrap.sh --profile developer --verify-only
```

The standard-profile implementation has passed native Monterey dry-run,
reconciliation, idempotency, verification, syntax, ShellCheck, and 72-column
presentation validation. Runtime artifacts remain under ignored `reports/`
and `backups/` locations.

The standard-profile validation above was originally based on standalone
commit `a75d2cc`. Developer-profile source from standalone commit `732e6ce` was
the import baseline. Commit `419f664` adds the current OpenAI tooling and
Monterey privacy handling.

On `rosebook`, direct developer verification detects `openai.chatgpt`, Node
`v22.22.3`, npm `12.0.2`, and Codex CLI `0.152.0`. The protected accessibility
preferences are also readable and correct with Terminal Full Disk Access.
Complete developer-profile reconciliation and idempotency checks remain
pending because Wireshark, Balena Etcher, and HandBrake are not yet installed.
