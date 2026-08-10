# LarryBootstrap Windows v1.0.1

This release hardens the packaged Windows bootstrap for clean provisioning
while preserving the BBS-inspired LarryLauncher front end.

## Included

- interactive Windows launcher with Install, Verify, Audit, Reports, and Exit actions
- `standard` profile selection, with reserved `homelab` and `developer`
  launcher choices
- optional short connection effect through `LARRY_ANIMATE=1`
- native Windows bootstrap and its PowerShell modules
- shared standard profile
- SHA-256 checksum beside the release archive
- primary IPv4 address in the launcher information box
- available space on the Windows system drive in the launcher information box
- Git as a required WinGet-managed standard package
- PATH refresh after WinGet installation stages
- a .NET drive-information fallback when `Get-Volume` is unavailable
- one automatic retry for failed required WinGet packages
- explicit WinGet prerequisite documentation

## Known boundaries

- PowerShell 7 is required.
- WinGet through Microsoft App Installer is required.
- This archive targets Windows only.
- Only `standard` has complete Windows manifests in this release.
- Windows Sandbox is not suitable for exact full-profile validation because its
  AppX, administrator-context, and networking-driver behavior differs from a
  normal Windows installation.
- Linux and macOS launcher packages will be delivered as later incremental releases.
- The package does not change the architecture of the separate Raspberry Pi `Larry` repository.

## Recommended first run

Use `launcher.ps1 -Action Verify -Profile standard` before selecting the full
installation workflow on a new system. The known Windows host passes with 36
checks, one expected Windows 10 WSL warning, and zero failures.
