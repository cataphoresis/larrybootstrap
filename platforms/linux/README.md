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

## Design rules

- Safe to rerun.
- Existing packages and applications are retained.
- One failed application should not stop unrelated installations.
- Aggressive service disabling and package removal are intentionally
  excluded from the bootstrap.
- Optimization changes are made only after reviewing audit evidence.
