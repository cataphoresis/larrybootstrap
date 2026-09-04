# LarryBootstrap Handoff

Updated September 4, 2026 after completing and validating the Rosebook
triple-boot recovery.

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

## Triple-boot recovery complete

rEFInd now presents one working entry each for macOS Monterey, Debian 13, and
Windows 10. All three entries were boot-tested successfully on `rosebook`.

Windows originally failed with `BlInitializeLibrary failed 0xc00000bb`. The
internal 512 GB Apple SSD had a stale hybrid MBR, causing Windows PE to treat it
as an MBR disk and expose only four of its six GPT partitions. Recovery:

- backed up sector zero and the GPT metadata outside version control;
- loaded `$WinPEDriver$/AppleSSD64/AppleSSD.inf` from the Boot Camp
  `OSXRESERVED` staging partition in Windows recovery;
- replaced the hybrid MBR with a conventional protective MBR while preserving
  all six GPT partitions and filesystems;
- assigned the 300 MiB EFI System Partition a temporary drive letter in Windows
  recovery and rebuilt the Microsoft EFI boot environment with `bcdboot`; and
- restored `EFI/Boot/bootx64.efi` to the verified Debian `grubx64.efi` fallback
  after using that path for diagnosis.

Post-repair `gdisk` and `sgdisk` validation reported a protective MBR, a valid
GPT, all six partitions, and no problems. Windows recovery saw the internal
disk as GPT, its BCD pointed to `EFI/Microsoft/Boot/bootmgfw.efi` and
`Windows/System32/winload.efi`, and the final rEFInd Windows entry booted.

`OSXRESERVED` remains intact because it contains Windows setup media and the
Apple WinPE/Boot Camp drivers. The misleading `bootmgr.efi` entry from that
volume and the obsolete legacy-Windows entry are not valid installed-Windows
boot paths. Do not recreate a hybrid MBR unless a future, independently
verified requirement explicitly calls for legacy BIOS booting.

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
