# LarryBootstrap Handoff

Updated September 2, 2026 after macOS Monterey developer-tooling validation and
the subsequent rEFInd installation problem.

## Current state

Commit `419f664` is pushed to `origin/main`. It updates the macOS bootstrap to:

- continue after Monterey blocks protected `com.apple.universalaccess`
  preference writes, reporting the required Terminal Full Disk Access action;
- verify inaccessible protected preferences as warnings instead of failures;
- install and verify `openai.chatgpt` only for the developer profile;
- install and verify `@openai/codex` through npm only for the developer profile;
- retain Node and npm in the official Intel compatibility direct-install path;
  and
- remove the obsolete custom-application inventory and verification policy.

Read-only validation on `rosebook` (`macOS 12.6.7`, `x86_64`) found Visual
Studio Code's `code` command, `openai.chatgpt`, Node `v22.22.3`, npm `12.0.2`,
and Codex CLI `0.152.0`. Developer verification reported both OpenAI checks and
both protected accessibility preferences as passing. Its overall result was
still incomplete because Wireshark, Balena Etcher, and HandBrake were absent;
Rust and Tauri remained optional warnings.

Shell syntax checks and `git diff --check` passed. ShellCheck was unavailable
on `rosebook`. No complete developer-profile install or idempotency rerun has
yet been performed after this change.

The next macOS Homebrew revision adopts a bottle-only Monterey policy. Formula
installation preflights the requested formula and missing dependencies; an
unavailable compatible bottle becomes a warning and manual/precompiled-binary
action rather than an automatic source compilation.

## Immediate boot recovery handoff

The attempted rEFInd installation did not complete successfully. Boot back into
Debian before continuing bootstrap validation. Treat bootloader recovery as the
immediate task and pause partition-layout work until normal boot selection is
restored.

Begin in Debian with read-only evidence: current UEFI boot entries, mounted EFI
System Partition, block-device layout, and the contents of the EFI directory.
Do not format the EFI System Partition, recreate the partition table, or remove
Apple, Windows, Debian, or fallback EFI loaders while diagnosing rEFInd.

## Linux validated state

The Debian 13 full bootstrap and post-reboot audit completed successfully with
zero warnings and zero failures. The final audit is recorded in the ignored
runtime log and report paths:

- `platforms/linux/logs/bootstrap-20260820-134945.log`
- `platforms/linux/reports/20260820-134945`
- `platforms/linux/reports/latest`

The validated application summary includes Node.js `v20.19.2`, npm `9.2.0`,
and the official Codex CLI `0.148.0`. The bootstrap now installs Node.js and npm
from Debian packages, installs `@openai/codex@latest` globally with npm, reports
their versions, and writes a dedicated `node-codex.txt` audit.

Command+C in VS Code now emits Ctrl+Shift+C. Context-aware VS Code bindings copy
editor or integrated-terminal selections without forwarding Ctrl+C/SIGINT to a
Codex CLI session. Command+V retains its context-aware terminal paste behavior.

The same run installed and applied the Qogir-Light XFCE appearance, retained the
original panel configuration as `xfce4-panel.xml.larrybootstrap-backup`, and
reloaded the Mac-style xbindkeys mappings. The final audit confirmed that
xbindkeys is running in the fresh XFCE session.

## Linux post-reboot validation

Completed successfully on August 20, 2026. In a fresh VS Code session:

- Command+C copied selected integrated-terminal text.
- Command+C with no selection did not interrupt or end the Codex session.
- Command+C copied selected editor text.
- Command+V pasted text in the integrated terminal.

The only bootstrap warning was the absence of a user Ed25519 SSH key. No key was
generated automatically; this is intentional and unrelated to the reboot gate.

## Execution note

Run installation commands from an interactive terminal. A command runner with
no TTY cannot display sudo's password prompt and fails at `sudo -v`; the VS Code
integrated terminal works when the command is entered manually.

The Linux changes were committed and pushed previously. The next macOS step is
to install or reconcile the remaining developer-profile applications, rerun
the full developer bootstrap, rerun it for idempotency, and confirm final
verification without failures.
