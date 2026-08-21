# LarryBootstrap Windows v1.0.1

This release hardens the packaged Windows bootstrap for clean provisioning
while preserving the BBS-inspired LarryLauncher front end.

## Included

- interactive Windows launcher with Install, Verify, Audit, Reports, and Exit actions
- `standard` Windows profile selection
- optional short connection effect through `LARRY_ANIMATE=1`
- native Windows bootstrap and its PowerShell modules
- shared standard profile
- SHA-256 checksum beside the release archive
- primary IPv4 address in the launcher information box
- available space on the Windows system drive in the launcher information box
- Git as a required WinGet-managed standard package
- GitHub CLI as a required WinGet-managed standard package
- stock Windows PowerShell 5.1 Stage 0 entry with automatic PowerShell 7 and
  WinGet establishment
- PATH refresh after WinGet installation stages
- a .NET drive-information fallback when `Get-Volume` is unavailable
- one automatic retry for failed required WinGet packages
- non-mutating Stage 0 prerequisite reporting in dry-run mode
- per-user WinGet execution for installers that reject administrator context
- delayed retries and deferred reporting for recoverable package downloads
- per-run deferred-package verification and a signed Debian VLC mirror fallback

## Known boundaries

- Stage 0 requires internet access to establish PowerShell 7 and WinGet.
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
