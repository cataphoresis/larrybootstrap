# LarryBootstrap Windows v0.1.1

This is the first packaged Windows release of the BBS-inspired LarryLauncher front end.

## Included

- interactive Windows launcher with Install, Verify, Audit, Reports, and Exit actions
- `standard`, `homelab`, and `developer` profile selection
- optional short connection effect through `LARRY_ANIMATE=1`
- native Windows bootstrap and its PowerShell modules
- shared standard profile
- SHA-256 checksum beside the release archive
- primary IPv4 address in the launcher information box
- available space on the Windows system drive in the launcher information box

## Known boundaries

- PowerShell 7 is required.
- This archive targets Windows only.
- Linux and macOS launcher packages will be delivered as later incremental releases.
- The package does not change the architecture of the separate Raspberry Pi `Larry` repository.

## Recommended first run

Use `launcher.ps1 -Action Verify -Profile standard` before selecting the full installation workflow on a new system.
