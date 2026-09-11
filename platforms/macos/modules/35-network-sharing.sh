#!/usr/bin/env bash
set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=modules/common.sh
source "$ROOT_DIR/modules/common.sh"
larry_section "SSH and authenticated SMB sharing"
share_path="${LARRY_SHARE_PATH:-/Volumes/LARRYSHARED}"
if [[ "${MACBOOK_DRY_RUN:-0}" == 1 ]]; then
    larry_info "Would enable Remote Login and SMB: OS read-only, LarryShare read/write ($share_path), no guests."
    exit 0
fi
if ! sudo /usr/sbin/systemsetup -setremotelogin on; then
    larry_warn "Remote Login could not be enabled. Give Terminal Full Disk Access and rerun."
fi
if [[ ! -d "$share_path" ]] || ! /sbin/mount | grep -Fq " on $share_path ("; then
    larry_fail "LarryShare is not mounted at $share_path; set LARRY_SHARE_PATH if needed."
    exit 1
fi
if ! /usr/sbin/sharing -h 2>&1 | grep -q -- '-R'; then
    larry_fail "This sharing command lacks the SMB read-only flag; configure OS sharing in System Settings."
    exit 1
fi
backup_dir="$ROOT_DIR/backups/sharing-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
/usr/sbin/sharing -l > "$backup_dir/shares.txt"
configure_share() {
    local record="$1" name="$2" path="$3" readonly="$4" existing
    existing="$(/usr/bin/dscl . -read "/SharePoints/$record" directory_path 2>/dev/null || true)"
    if [[ -n "$existing" ]]; then
        if [[ "$existing" != "directory_path: $path" ]]; then
            larry_fail "Existing share $record has a different path; leaving it unchanged."
            return 1
        fi
        sudo /usr/sbin/sharing -e "$record" -S "$name" -s 001 -g 000 -R "$readonly"
    else
        sudo /usr/sbin/sharing -a "$path" -n "$record" -S "$name" -s 001 -g 000 -R "$readonly"
    fi
}
configure_share LarryBootstrap-OS OS / 1 || exit 1
configure_share LarryBootstrap-LarryShare LarryShare "$share_path" 0 || exit 1
sudo launchctl enable system/com.apple.smbd || exit 1
sudo launchctl kickstart system/com.apple.smbd || exit 1
larry_info "In Sharing > File Sharing > Options, enable SMB for your account and enter its password."
larry_info "SMB uses native macOS account/filesystem permissions; no guest access or blanket ACL changes."
larry_info "Connect using smb://$(hostname)/OS and smb://$(hostname)/LarryShare."
