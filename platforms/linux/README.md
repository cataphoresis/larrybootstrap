# LinuxBook Bootstrap

Reusable Debian 13 bootstrap and auditing tools for the MacBook9,1
triple-boot Linux installation.

## Modes

Core installation:

    ./bootstrap.sh core

Full workstation installation:

    ./bootstrap.sh full

Run full installation from an interactive terminal so `sudo` can display its
password prompt. Non-interactive command runners without a TTY fail during the
sudo preflight by design.

Capture a fresh system audit without installing anything:

    ./bootstrap.sh audit

## Mac-style keyboard shortcuts

On the MacBook9,1 XFCE profile, the bootstrap installs and starts xbindkeys with
the following X11 mappings:

- Command+C copies.
- Command+V pastes.
- Command+A selects all.
- Command+Tab activates the next visible application window on the current desktop.
- Command+Shift+Tab activates the previous visible application window.

Copy and paste are translated to Ctrl+Shift+C and Ctrl+Shift+V in
`xfce4-terminal`; other applications receive Ctrl+C and Ctrl+V. Window switching
uses direct xdotool window activation instead of XFWM's built-in Super+Tab.

The letter bindings use the validated X11 Super modifier and physical keycodes
for this MacBook keyboard. Tab uses symbolic xbindkeys syntax so X11 resolves its
keycode and the Shift modifier for the active keyboard map.

In VS Code, Command+C emits Ctrl+Shift+C and uses context-aware bindings to copy
selected terminal or editor text. With no terminal selection it is a no-op, so
it cannot send Ctrl+C/SIGINT and end a Codex CLI session. Command+V emits
Shift+Insert, and the integrated terminal binds Ctrl+V, Ctrl+Shift+V, and
Shift+Insert to terminal text paste. This prevents a raw Ctrl+V from reaching
Codex CLI's image-paste handler when pasting text.

## XFCE appearance and VS Code

Full mode installs the pinned Qogir-Light GTK theme and Qogir icon set from
their upstream releases. It applies Inter as the desktop font, keeps one
34-pixel panel at the bottom, replaces the Applications menu with Whisker Menu,
and adds the transparent rounded dark Whisker styling from OpenDesktop item
1732225. The original panel XML is retained as
`xfce4-panel.xml.larrybootstrap-backup` before the first layout change.

VS Code receives the official OpenAI Codex extension, Fira Code editor and
terminal typography, and context-aware integrated-terminal copy/paste bindings.
Full mode also installs Debian's Node.js and npm packages, then installs or
updates the official `@openai/codex` CLI package globally with npm.

Authentication remains interactive. On first use, run `codex` and choose
**Sign in with ChatGPT**. In VS Code, press Ctrl+Shift+P and run
**Codex: Open Codex Sidebar**, then sign in with the same ChatGPT account.

## Reports

The newest report is available at:

    reports/latest

Reports and logs use repository-relative paths in unified output and remain in
ignored runtime directories.

## Implemented workstation scope

- Debian 13 package repair, updates, core/full package sets, and multiarch
- Firefox, Chromium, VLC, Spotify, 1Password, Visual Studio Code, Geany,
  Moonlight, Heroic, Steam, Android platform tools, GitHub CLI, Node.js, npm,
  and the official OpenAI Codex CLI
- SSH client/server configuration and homelab/networking utilities
- SSD TRIM, BOOTCAMP NTFS integration, and conservative APFS handling
- installer cache validation, application version/source reporting, and
  read-only audit mode
- idempotent reruns, Bash syntax validation, ShellCheck, plain logs, and the
  shared 72-column LarryBBS presentation contract

## Design rules

- Safe to rerun.
- Existing packages and applications are retained.
- One failed application should not stop unrelated installations.
- Aggressive service disabling and package removal are intentionally
  excluded from the bootstrap.
- Optimization changes are made only after reviewing audit evidence.

## Validation state

The updated unified Linux full mode completed natively on Debian 13 on August
20, 2026 with zero failures. The validated application summary reported Node.js
`v20.19.2`, npm `9.2.0`, and Codex CLI `0.148.0`. The only warning was the
intentional absence of an automatically generated user Ed25519 SSH key.

Post-reboot validation in a fresh XFCE and VS Code session passed all managed
Command+C and Command+V behaviors. The final audit completed with zero warnings
and zero failures, including the live xbindkeys process check.
