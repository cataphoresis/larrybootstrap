# September 14 Windows reconciliation

On ROSEBOOK-WINDOW (Windows 10 Pro 21H2, build 19044), the elevated full
standard bootstrap passed 54 checks with one known `wsl --mount` warning and
zero failures. Report: `platforms/windows/reports/verify-2026-09-14_12-53-23.txt`.
Git preflight confirmed clean `main` equal to fetched `origin/main` at
`b8b9bc8` before these edits. Session changes are not yet committed or pushed.

- The first run installed FFmpeg, Python, DiskGenius, optional Paragon APFS,
  and Etcher, then stopped at SMB with access denied. Stage 0 now requests
  Windows Administrator elevation before full apply; the elevated rerun passed.
- FileZilla 3.71.1 is installed and verified. The old SourceForge endpoint
  returned HTML on September 3 and FileZilla was incorrectly allowed to pass
  as optional. It is now required, with a signed local Downloads installer
  fallback when the remote download is blocked.
- Visual C++ v14 x64 is required, using the verified Microsoft redirect
  `https://aka.ms/vs/17/release/vc_redist.x64.exe`. The supplied underscore
  spelling led to Bing. Existing x64 runtime 14.51.36247 is detected and kept.
- Direct-installer waiting now tracks the installer rather than all child
  processes; Etcher had opened its app and held up the original run. Fresh
  installation of the revised wait path remains untested; installed-app rerun
  and existing Etcher resolver regression checks passed.
- Firefox's five mandatory extension policies, current ChatGPT desktop, and
  authenticated OS/LarryShare SMB shares all passed verification.
- The ordered taskbar policy is applied and its XML/registry checked: Firefox,
  VS Code, Larry PowerShell, Notepad++, Explorer, FileZilla, 1Password, Spotify,
  Balatro. 1Password is already installed/running as a packaged app; the script
  now resolves its AppUserModelID instead of requiring a nonexistent .lnk.

Pending: sign out/in and visually validate icon order. Large native taskbar
buttons are enabled, but exact Debian 72/60 sizing is not yet achieved. The
user's preference for whole-display scaling versus a separate dock is pending;
display scaling was not changed. PowerToys workspace captures and a separate
clean-machine/full-VM provisioning test remain outstanding.

Read-only taskbar measurement found 2304-pixel width, 60-pixel height and
144 DPI (150% scale) after enabling large buttons. This is still smaller than
the requested Debian panel. No separate dock was installed.

The elevated health audit completed with four warning categories and no
collection errors (`audit-2026-09-14_13-01-19.txt`). Follow-up priorities:

1. Investigate earlier DNS Client 1023 policy-table errors and VBoxNetLwf 12
   errors if networking symptoms recur. Effective NRPT rules were readable
   afterward; Tailscale and the VirtualBox filter service were running.
2. Review boot-time ACPI timeout, processor firmware throttling, WudfRd and
   duplicate disk-identifier events without altering the triple-boot disks.
3. Fix AppX inventory collection under PowerShell 7 by using native Windows
   PowerShell, as the launcher now does for Get-StartApps. The warning does
   not mean installed Store apps are missing.
4. Improve audit classification: E: and G: are removable slots with no medium
   (null capacity), not full disks. Stopped updater services need trigger/task
   context before being called failures. Steam is running despite an earlier
   service-start timeout. C: had about 25 GB free during the audit.

Direct share-ACL inspection confirmed only the current account: OS Read and
LarryShare Change. Runtime detection regression cases and existing Etcher
resolver/redirect rejection checks passed, as did PowerShell parsing and
`git diff --check`.

# September 11 parity and Debian power update

## September 11 bootstrap parity follow-up

Commit `e17cae4` is pushed to `origin/main`. It brings the three platform
bootstraps into alignment for PIA, Tailscale, FFmpeg, ChatGPT, Python, Etcher,
Firefox extension policy, authenticated SMB shares, SSH, APFS compatibility,
and native quick-launch scripts. Retired media/development tools (HandBrake,
MakeMKV, MKVToolNix, yt-dlp, Rust/Tauri, Heroic, and Geany) are no longer part
of the active bootstrap paths. Documentation and implementation should be
updated together when these platform contracts change.

The approved Debian panel size is now 72 pixels with 60-pixel icons, applied
live and encoded in both appearance and quick-launch setup. The earlier
48/40 values and custom 1Password SVG had survived reboot; no icon repair was
needed. User confirmed the larger size is better.

Battery reports 37.71 Wh versus 42.35 Wh design (89.045%), 183 cycles. Previous
boot log records lid closed at September 10 15:30 with no suspend entry. XFCE
4.20 was using its implicit lock-only lid default and held the lid inhibitor.
Explicit suspend-on-lid-close on AC/battery plus lock-screen is now applied,
backed up, and included in core/full/desktop. An actual close/reopen test and
longer sleep-discharge measurement remain pending. Deep sleep is selected;
there is no swap and XFCE reports hibernate unavailable. Boot/resume settings
were not changed.

Tailscale installer/manifest coverage is added to all three platforms. Debian
focused installation is `bash bootstrap.sh tailscale`, followed by separate
`sudo tailscale up` sign-in. Debian installation and authentication were completed by the user and verified
on September 11: Tailscale 1.102.4, tailscaled enabled/active, backend Running.
See PLATFORM_PARITY.md for the full comparison and other parity corrections.
All existing September 9 work is preserved in the subsequent parity commits.

# September 9 desktop update

Debian's existing 34/28-pixel panel/icon defaults were still active but too
small. The new defaults are 48/40 pixels. The focused Linux script backed up
and applied Firefox, VS Code, Terminal, Mousepad, Thunar, FileZilla, 1Password,
Spotify, and Balatro in order. macOS keeps Finder first by user preference.
Windows and macOS focused setup scripts are prepared but need native execution
and validation; see the root README. Changes remain uncommitted for review.

# LarryBootstrap Handoff

Updated September 4, 2026 after completing the Rosebook triple-boot recovery
and the final Debian desktop and SSH-key customizations.

## Current state

Commit `2d168aa` is pushed to `origin/main`; the working tree was clean at
handoff. The earlier macOS bootstrap work in `419f664`:

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
still incomplete because Wireshark and Balena Etcher were absent;
The optional developer-tool checks from that revision have since been retired.

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
zero warnings and zero failures. That historical final audit used the ignored
runtime log and report paths:

- `platforms/linux/logs/bootstrap-20260820-134945.log`
- `platforms/linux/reports/20260820-134945`

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

The September 4 desktop-only run added and visually validated a compact quick
launch area in this order: Firefox, VS Code, Terminal, Mousepad, Thunar,
FileZilla, and Balatro. XFCE uses 144 DPI, new interactive shells opened in home
start in `/mnt/larryshare/Projects`, and Command/Super+Left and +Right tile the
active window to the corresponding half of the screen. These settings are
available through `./bootstrap.sh desktop` and are committed in `e7d351e`.

Linux now requires a valid per-user Ed25519 SSH key. The focused
`./bootstrap.sh ssh` run generated `~/.ssh/id_ed25519`, validated its type and
permissions, reported its fingerprint, and confirmed that the SSH server is
enabled and active. The idempotent policy is committed in `2d168aa`.

Two non-blocking Debian cleanup items remain:

- `reports/latest` cannot be created as a symbolic link because this checkout
  resides on exFAT; timestamped audit reports are still written correctly; and
- Raspberry Pi Imager is absent and therefore appears as failed in the
  application-status table, although the focused desktop and SSH runs each
  completed with zero bootstrap failures.

## Linux post-reboot validation

Completed successfully on August 20, 2026. In a fresh VS Code session:

- Command+C copied selected integrated-terminal text.
- Command+C with no selection did not interrupt or end the Codex session.
- Command+C copied selected editor text.
- Command+V pasted text in the integrated terminal.

The historical post-reboot run warned that no user Ed25519 SSH key existed.
That condition is resolved by the required-key policy and successful focused
SSH run described above.

## Next macOS session

Boot macOS through the verified rEFInd macOS entry, open an interactive
Terminal, and pull `origin/main`. The next substantive work is:

1. confirm the shared `LARRYSHARED` volume and repository are writable;
2. install or reconcile Wireshark and Balena Etcher for the
   developer profile under the bottle-only Monterey policy;
3. rerun the complete developer-profile bootstrap;
4. rerun it a second time to verify idempotency; and
5. review the final report, allowing only documented unavailable-compatible-bottle warnings.

Do not alter the GPT, recreate a hybrid MBR, remove `OSXRESERVED`, or change EFI
loaders during the macOS bootstrap work. The three operating systems and their
rEFInd entries are already verified.

## Execution note

Run installation commands from an interactive terminal. A command runner with
no TTY cannot display sudo's password prompt and fails at `sudo -v`; the VS Code
integrated terminal works when the command is entered manually.

The Linux and boot-recovery changes are committed and pushed. Continue with the
macOS checklist above.
