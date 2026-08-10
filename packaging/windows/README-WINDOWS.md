# LarryBootstrap for Windows

This archive contains the tested Windows LarryLauncher and every repository component it needs at runtime.

## Requirements

- Windows 10 or Windows 11
- PowerShell 7 (`pwsh.exe`)
- WinGet through Microsoft App Installer
- internet access for installation operations
- administrator approval only when an individual installation or setting requires it

## Start the launcher

1. Extract the entire ZIP to a normal folder. Do not run the script from inside the ZIP preview.
2. Open PowerShell 7 in the extracted folder.
3. Run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\launcher.ps1
```

The execution-policy change applies only to that PowerShell process. You can also run a noninteractive verification:

```powershell
.\launcher.ps1 -Action Verify -Profile standard
```

Use the `standard` profile. The launcher currently exposes `homelab` and
`developer` as reserved choices, but the packaged Windows runtime does not yet
contain their package/direct-install manifests; install or verification with
those profiles is not release-ready.

WinGet is a prerequisite, not something this archive bootstraps. Git is managed
by the standard profile and may be absent before the first installation.

## Verify the download

From the folder containing the ZIP and `.sha256` file:

```powershell
(Get-FileHash .\LarryBootstrap-Windows-v1.0.1.zip -Algorithm SHA256).Hash.ToLower()
Get-Content .\LarryBootstrap-Windows-v1.0.1.zip.sha256
```

The two hashes should match.

## Important behavior

The interactive **Install** action changes workstation software and settings after confirmation. Start with **Verify configuration** or **Run system audit** when evaluating the package on another computer.

Generated reports remain local under `platforms\windows\reports` and are not part of the downloaded release.

Windows Sandbox is not an accepted full-profile test target for this release.
Its Windows 10 image lacks WinGet initially, does not support AppX deployment
reliably, rejects Spotify from its elevated administrator context, and cannot
safely validate VPN networking drivers. Use a conventional VM or separate
machine for exact clean-install testing.
