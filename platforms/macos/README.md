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

Amphetamine is a manual App Store download, with a clickable URL printed by
the workstation stage. FileZilla uses its existing compatibility installer.
CotEditor, Steam, Tailscale and GPT fdisk are also part of the native profiles.

## Command-line tools

- git
- ffmpeg
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

The developer profile extends standard with Python, CMake, pkg-config,
Wireshark, Balena Etcher, Private Internet Access and Raspberry Pi Imager.
Non-minimal profiles install Codex CLI and the OpenAI VS Code extension.
Node uses the compatibility-managed official Intel binary on Monterey.
FFmpeg is included across profiles: reviewed Intel binaries on Intel and a
Homebrew bottle on Apple Silicon.

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
pending; the current expanded workstation/network stages also need native validation.

## Ordered bottom launchers

See the [shared launcher standard](../../README.md#bottom-launcher-standard)
for the focused setup command, prerequisites, backups, and platform behavior.

## ChatGPT, browser policy, and network access

On macOS 14+, the workstation stage installs the current official `chatgpt`
cask (Intel and Apple Silicon). On macOS 13 and earlier it detects MacGPT or
prints https://goodsnooze.gumroad.com/l/menugpt for manual download into
Applications. Amphetamine prints https://apps.apple.com/us/app/amphetamine/
plus the full App Store ID link. Neither download requires a bootstrap purchase.

All five Firefox extensions come from `common/profiles/firefox.json` and use
mandatory `force_installed` policy. Restart Firefox after the policy is applied.

The network stage enables Remote Login and native SMB sharing: `OS` is
read-only, `LarryShare` read/write, guest access off. It expects the shared disk
at `/Volumes/LARRYSHARED`; set `LARRY_SHARE_PATH` for another mount path. Enable
your account under File Sharing > Options and enter its password locally.
Terminal may need Full Disk Access for Remote Login. Existing filesystem
permissions remain effective; the bootstrap does not broaden them recursively.

GPT fdisk (`gdisk`) is an open-source advanced GPT partition-table tool, not a
GUI APFS filesystem resizer. The bootstrap only installs it and never modifies
partition tables. See the root workstation update notes for tool limitations.
