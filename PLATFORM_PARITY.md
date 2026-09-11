# Platform parity review — September 11, 2026

This compares executable bootstrap paths and their manifests, not the contents
of machines that happened to have applications installed earlier. Windows has
one standard profile; Debian has core/full; macOS has minimal/standard/developer
and a homelab profile file. Compare Windows standard, Debian full, and macOS
standard for daily workstation parity. macOS developer/homelab add more tools.

The main source of drift: `common/profiles/standard.json` is documentation of
intent. None of the three native installers consumes it. Packaging the JSON
does not make the declared applications install. The platform manifests and
modules must be updated together until a shared reconciliation layer exists.

## Common workstation applications

| Capability | Windows | Debian | macOS | Review result |
|---|---|---|---|---|
| Firefox | WinGet | APT ESR | Homebrew cask | All three |
| Secondary browser | Chromium, optional | Chromium now in core APT | Safari built in | Debian declaration previously missing |
| VS Code | WinGet | Microsoft APT | Homebrew cask | All three |
| Node/npm | WinGet LTS | Debian full APT | Official binary compatibility path | Added Node intent to standard/homelab; developer already had it |
| Codex CLI | npm | npm | npm | Expanded macOS from developer-only to every non-minimal profile |
| Codex VS Code extension | `openai.chatgpt` | `openai.chatgpt` | `openai.chatgpt` | Same expansion on macOS; CLI and extension are separate installs |
| File browser | Explorer built in | Thunar explicitly in core | Finder built in | Finder remains first in Dock by user preference |
| Terminal | PowerShell 7 prerequisite | XFCE Terminal explicitly in core | Terminal built in | Native equivalents |
| FileZilla | Direct installer, optional | Full APT | Dedicated direct-install module | All three; Windows can skip an unavailable optional download |
| 1Password | WinGet | Vendor APT | Homebrew cask | All three |
| Spotify | User-context WinGet | Flatpak | Homebrew cask | All three |
| VLC | WinGet | Core APT | Homebrew cask | All three |
| Archives | 7-Zip | p7zip/unzip/zip/File Roller | Keka | Native equivalents |
| Moonlight | WinGet | Added Flatpak install | Homebrew cask | Debian README/shared intent previously exceeded implementation |
| Tailscale | Added `Tailscale.Tailscale` | Added vendor APT + enabled service | Added `tailscale-app` cask, all profiles | Previously absent from all installer paths; existing Mac inventory was not installation logic |
| Steam | Added `Valve.Steam` | Full APT | Added cask to non-minimal profiles | Previously only Debian installed it |
| Balatro | Steam launch shortcut | Steam launch shortcut | Existing app required by Dock script | License, game download and Steam sign-in remain manual |
| Git / GitHub CLI | Both standard | Git core, gh full | Both standard | All three |

New native application declarations still need Windows/macOS execution and
verification. Existing macOS app paths are recognized before cask installation,
including Tailscale, CotEditor and Steam. Monterey cask availability can limit
fresh installs; the bootstrap reports unsupported/unavailable applications.

## Applications and utilities present on fewer platforms

These are retained differences, not an instruction to install every utility on
every OS. OS plumbing such as APT, WinGet and Homebrew is intentionally native.

| Application or utility group | Coverage in the bootstrap |
|---|---|
| Private Internet Access | Windows standard; macOS developer/homelab; absent Debian |
| Wireshark | Debian full; macOS developer/homelab; absent Windows |
| Raspberry Pi Imager | Debian installer; macOS manual-app intent in developer/homelab; absent Windows |
| Balena Etcher | Debian installer; macOS developer/homelab; absent Windows |
| FFmpeg | Debian core; macOS standard/developer compatibility path and homelab formula; absent Windows |
| Python | Debian full; macOS developer/homelab; absent Windows standard |
| CMake / pkg-config | macOS developer explicitly; Debian build-essential is not equivalent; absent Windows |
| PowerToys / FancyZones / Workspaces | Windows only; Rectangle supplies window tiling on macOS; custom XFCE bindings on Debian |
| Stats / Amphetamine | macOS; Amphetamine is manual in standard/developer |
| Android adb / fastboot / USB rules | Debian full only |
| GParted, exFAT/NTFS tools, SMART, sensors, Mesa/VA diagnostics, firmware/microcode | Debian full only |
| nmap, iperf3, tcpdump, traceroute, DNS utilities, ethtool, whois, mtr, net-tools | Debian full only |
| htop, btop, ncdu, tree, lsof, tmux, screen, rsync, mediainfo | Debian core explicitly; other platforms do not declare equivalent package sets |
| gvfs-backends / smbclient | Debian core; Explorer/Finder supply native SMB browsing on Windows/macOS |
| pip/pipx/venv, build-essential, ShellCheck | Debian full explicitly |
| ripgrep, fd, bat, eza, fzf, yq, mosh, serial-terminal tools, avahi-utils | Mentioned in legacy Linux `modules/homelab.sh`, which is **not executed** by bootstrap |

## Services and customizations

| Behavior | Windows | Debian | macOS |
|---|---|---|---|
| Tailscale service/app | Vendor installer | Enables `tailscaled` | Vendor app; user launches/approves extension |
| Tailscale account and routing | User sign-in | User `sudo tailscale up` | User sign-in |
| SSH server + required Ed25519 key | No corresponding stage | Configures server and key | No corresponding stage |
| SSD TRIM | Native OS behavior | Enables periodic fstrim | Native OS behavior |
| Filesystem integration | Separate compatibility stage | BOOTCAMP NTFS; conservative APFS handling | No equivalent mounting stage |
| Firefox extension policy | uBlock Origin, SponsorBlock, Privacy Badger, 1Password | Not managed | Not managed |
| VS Code fonts/theme/keybindings | Installs extension; no matching typography setup | Fira Code, dark theme, contextual terminal copy/paste | Installs extension; no matching typography setup |
| Shell experience | Managed PowerShell profile, history, editor, shortcut; `~/Projects` | Interactive home shells start in shared Projects | No equivalent shell profile stage |
| Desktop theme / fonts | Windows settings | Qogir/Inter/Fira Code, 144 DPI, Whisker | Native defaults |
| Window tiling and shortcuts | PowerToys | Mac keyboard translation, Command+arrows, window switching | Rectangle and native Command keys |
| File browser defaults | Explorer extensions/recent/frequent settings | No comparable Thunar preference stage | Finder path/status bars, list view, extensions, folder-first |
| Trackpad, keyboard repeat, screenshot defaults | No corresponding stage | No corresponding stage beyond keyboard remapping | Explicitly configured |
| Reduced animation | Registry preferences | No equivalent general stage | Dock/accessibility preferences |
| Lid-close suspend | No explicit policy | Now explicit in core/full/desktop on MacBook XFCE | No explicit sleep policy; native defaults |
| Audit/verification | Dedicated verify and health audit | System/app report; now includes power/Tailscale | Profile verifier and inventories |

## Quick launch and panel findings

The common order is Firefox, VS Code, terminal, lightweight editor, file browser,
FileZilla, 1Password, Spotify, Balatro. On macOS Finder is first, then the other
eight in order. The focused scripts implement this intent, but only Debian
currently invokes launcher setup from its full bootstrap. Windows/macOS scripts
remain explicit follow-up commands; this is a remaining integration gap.

Windows uses a taskbar layout policy and needs a sign-out/in and native review.
macOS uses dockutil, keeps unrelated pins after managed ones and requires all
listed apps including Balatro before changing the Dock. These are not yet
equivalent to Debian's skip-missing-launchers behavior. Do not claim native
launcher parity until those two scripts have been executed and visually checked.

On September 11 the Debian panel still had its saved 48-pixel size, 40-pixel
icons and 144 DPI. The selected 1Password SVG remained in place. The user
clarified that sizing was the issue and approved 72/60 pixels after the live
change. Both appearance and launcher configuration now use 72/60, and the
existing icon is retained. A reboot check is still needed for the new size.

## Battery and lid-close investigation

Rosebook reports 37.7075 Wh full versus 42.3465 Wh design (89.045%), 183 charge
cycles. It was charging during inspection. Those readings show modest wear;
they do not measure sleep discharge or prove every aspect of battery health.

The previous boot recorded lid close on September 10 at 15:30:12 with no
subsequent suspend entry in the supplied filtered system journal. XFCE held
the lid-switch inhibitor, and no lid action was explicitly configured. The
[XFCE 4.20 default](https://raw.githubusercontent.com/xfce-mirror/xfce4-power-manager/xfce4-power-manager-4.20.0/common/xfpm-config.h)
is screen lock only. This supports failure to enter suspend as the immediate
explanation for the drain. Explicit suspend on AC/battery with screen locking
is now applied and backed up. Physical lid-close/resume validation is pending.

The kernel selects deep sleep. XFCE reports suspend available and authorized,
but hibernate unavailable. There is no swap. Suspend will still consume some
power; suspend-then-hibernate would require separately configuring and testing
swap/resume, particularly carefully on this triple-boot machine. No bootloader,
partition, swap, or forced-suspend changes were made during this review.

## Sources and validation limits

- [Tailscale Debian packages](https://pkgs.tailscale.com/stable/#debian-trixie)
  supply the repository/keyring used by the focused installer.
- [Homebrew Tailscale app](https://formulae.brew.sh/cask/tailscale-app) is the
  GUI app cask, distinct from the CLI-only formula.
- [Codex CLI](https://learn.chatgpt.com/docs/codex/cli) and
  [Codex IDE extension](https://learn.chatgpt.com/docs/codex/ide) document the
  two installation surfaces; existing package/extension IDs are retained.

Debian desktop settings were checked live. Tailscale 1.102.4 was subsequently
installed and authenticated by the user; verification found tailscaled enabled
and active with backend state Running. Shell syntax/static checks and
mocked Tailscale installer control-flow checks cover the changed Bash code.
Windows/macOS native installation and launcher behavior remain unverified.
