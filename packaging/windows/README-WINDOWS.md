# LarryBootstrap for Windows

This archive contains the tested Windows LarryLauncher and every repository component it needs at runtime.

## Requirements

- Windows 10 or Windows 11
- internet access for installation operations
- an elevated shell for first-run prerequisite installation or repair

## Start the launcher

1. Extract the entire ZIP to a normal folder. Do not run the script from inside the ZIP preview.
2. Open Windows PowerShell as Administrator in the extracted folder.
3. Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File .\bootstrap.ps1 -Profile standard
```

The bypass applies only to that process. Stage 0 establishes PowerShell 7 and
WinGet without requiring Git or GitHub CLI. After the first bootstrap, run the
interactive launcher from PowerShell 7:

```powershell
.\launcher.ps1
```

Windows supports the `standard` profile. Git and GitHub CLI are managed by its
normal WinGet package stage and may both be absent before the first run.

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
