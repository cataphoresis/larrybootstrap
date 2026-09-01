# LarryBootstrap

LarryBootstrap recreates the same remote-first workstation experience across
Windows, Linux, and macOS. Platform implementations remain native to each
operating system while shared profiles describe portable workstation intent.

## Repository layout

```text
common/
  profiles/            Shared application and workstation intent
  platform-baselines.json  Golden standalone source revisions
platforms/
  windows/             PowerShell and WinGet implementation
  linux/               Bash, APT, and Flatpak implementation
  macos/               Bash and Homebrew implementation
bootstrap.ps1          Windows entry point
bootstrap.sh           macOS/Linux entry point
launcher.ps1           Interactive Windows LarryLauncher
launcher.sh            Interactive macOS/Linux LarryLauncher
```

## LarryLauncher

LarryLauncher is a thin BBS-inspired front end for the native bootstrap. It
does not duplicate installation logic. Its menu provides install, verify,
audit, and recent-report actions, then delegates to the platform entry point.

Verification checks the workstation against the selected bootstrap profile.
Audit is a separate read-only system-health snapshot covering system uptime,
storage, networking, services, recent event warnings, startup entries, pending
reboots, and Windows Security status.

Windows:

```powershell
.\launcher.ps1
.\launcher.ps1 -Action Verify -Profile standard
```

macOS or Linux:

```bash
./launcher.sh
./launcher.sh --action verify --profile standard
```

Selecting a full installation from the interactive menu requires confirmation.
Passing an explicit install action is intended for scripts and runs immediately.
Set `LARRY_ANIMATE=1` to enable the short connection effect in an interactive
terminal; redirected and unattended output remains delay-free.

## Mandatory cross-OS handoff preflight

Before editing code on any operating system:

1. Confirm the working directory, repository root, `origin` URL, and branch.
2. Inspect the working tree and preserve all existing changes.
3. Fetch GitHub and inspect local/remote divergence.
4. Bring the checkout fully current before writing code.
5. Stop if the checkout is stale, conflicted, dirty unexpectedly, or belongs
   to the wrong repository.
6. Before switching operating systems, commit and push all approved work.
7. Verify that local `HEAD` equals `origin/main` after synchronization.

Never bypass divergence with a force-push, destructive reset, or blind pull.
Use fast-forward-only synchronization when the working tree is clean and the
local branch has no unique commits:

```bash
pwd
git rev-parse --show-toplevel
git remote get-url origin
git status --short --branch
git fetch origin
git log --oneline --decorate --graph --left-right HEAD...origin/main
git pull --ff-only
git status --short --branch
git rev-parse HEAD
git rev-parse origin/main
```

If local and remote histories have diverged, inspect both histories and their
file-level differences before choosing a rebase or merge.

## Usage

Windows, from an elevated stock Windows PowerShell prompt:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File .\bootstrap.ps1 -Profile standard
```

The process-scoped execution-policy bypass does not change the machine or user
execution policy. Stage 0 establishes PowerShell 7 and a functional WinGet,
then opens a new elevated PowerShell 7 console for the normal Windows pipeline
and closes the original Windows PowerShell process. Git and GitHub CLI remain
ordinary WinGet-stage packages. `-DryRun` never installs or repairs
prerequisites; when they are missing it reports the required actions and stops
before the normal dry run. Once prerequisites exist, `-VerifyOnly` and
`-DryRun` are forwarded unchanged.

macOS:

```bash
./bootstrap.sh --profile standard
./bootstrap.sh --profile standard --verify-only
```

Linux:

```bash
./bootstrap.sh full
./bootstrap.sh audit
```

The root launchers detect or enforce the current platform and delegate every
option to the corresponding native bootstrap. Platform-specific READMEs
document additional profiles, behavior, and recovery details.

The current cross-session state and remaining validation steps are recorded in
[`HANDOFF.md`](HANDOFF.md).

Cross-platform application intent is reconciled deliberately after native
platform behavior is imported and verified. The revisions recorded in
`common/platform-baselines.json` are the source-of-truth checkpoints for this
integration milestone.

The shared standard profile reconciles Firefox, the platform-native secondary
browser, Visual Studio Code, Node.js/npm, Codex CLI and its VS Code extension,
a lightweight editor, 1Password, VLC, Spotify, an archive utility, and
Moonlight. Applications without a safe or useful
implementation on all three systems remain platform-specific.

## Terminal style

LarryBootstrap uses an intentionally retro BBS-inspired terminal style on all
three operating systems. Main commands open with an ASCII banner and consistent
profile, user, computer, system, shell, and start-time details. Status output
uses `[ OK ]`, `[WARN]`, `[FAIL]`, and `[INFO]` markers. The shared presentation
contract is 72 columns, including redirected output. Any future animation must
be lightweight, terminal-only, and automatically disabled for redirected
output, logs, and unattended runs.

## Browser standard

- Windows and Linux: Firefox primary, Chromium secondary.
- macOS: Firefox primary, built-in Safari secondary.

## History and releases

The Windows, Linux, and macOS repositories were imported with their original
commit histories intact. Native validation across Windows, Debian 13, and
macOS Monterey is recorded by `unified-v1.0.0`. Windows clean-provisioning
hardening is recorded by `windows-v1.0.1` at commit `bab829f`.

The original standalone repositories remain recovery sources until the unified
bootstrap also completes an exact full-profile test on a separate physical
machine or conventional VM. Windows Sandbox was evaluated and rejected for
this purpose because its Windows 10 image does not support the required AppX
and networking-driver installers reliably.

`common/platform-baselines.json` records synchronized macOS developer-profile
source `732e6ce` as the original import checkpoint. The unified macOS
implementation now extends that baseline with Monterey privacy handling and
developer-profile OpenAI tooling at commit `419f664`.

On the validated Intel Monterey host, the `openai.chatgpt` VS Code extension
and Codex CLI are detected successfully. Node and npm remain
compatibility-managed from the official Intel Node distribution instead of a
Homebrew Node formula. Protected `com.apple.universalaccess` writes now warn
with a Full Disk Access action instead of aborting the remaining defaults.

## Packaging releases

The current packaged release targets Windows and preserves the tested
`launcher.ps1` behavior. From PowerShell 7:

```powershell
.\scripts\package-windows.ps1 -Version 1.0.1
```

The command creates a versioned ZIP and SHA-256 checksum in `dist/`. The ZIP
contains only the shared profile and Windows runtime dependencies needed by the
launcher; it excludes the Linux and macOS implementations.

Current packaging state:

1. Windows `v1.0.1` — packaged and validated on the known Windows host.
2. Linux — native implementation validated; standalone launcher packaging is
   still future work.
3. macOS — native implementation validated; standalone launcher packaging is
   still future work.

The remaining macOS gate is a complete developer-profile reconciliation and
idempotency run after the profile's missing applications are installed. The
OpenAI extension, Codex CLI, and protected-preference verification paths have
already passed direct validation on the known Monterey host. The next
clean-install gate remains an exact Windows standard-profile installation on a
separate physical machine or full VM, followed by idempotency and final
verification. Do not retire the standalone recovery repositories before both
tasks pass.
