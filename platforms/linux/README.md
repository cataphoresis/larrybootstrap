# LinuxBook Bootstrap

Reusable Debian 13 bootstrap and auditing tools for the MacBook9,1
triple-boot Linux installation.

## Modes

Core installation:

    ./bootstrap.sh core

Full workstation installation:

    ./bootstrap.sh full

Capture a fresh system audit without installing anything:

    ./bootstrap.sh audit

## Reports

The newest report is available at:

    reports/latest

Reports and logs use repository-relative paths in unified output and remain in
ignored runtime directories.

## Implemented workstation scope

- Debian 13 package repair, updates, core/full package sets, and multiarch
- Firefox, Chromium, VLC, Spotify, 1Password, Visual Studio Code, Geany,
  Moonlight, Heroic, Steam, Android platform tools, and GitHub CLI
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

The unified Linux implementation was validated natively on Debian 13 and
published in commit `102f193` (`Finalize Linux bootstrap release`). The audit
is read-only, a second full run is idempotent, and the standalone repository is
not modified by unified integration work.
