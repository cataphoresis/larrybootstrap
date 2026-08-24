#!/usr/bin/env bash
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$PROJECT_DIR/modules"
LOG_DIR="$PROJECT_DIR/logs"
MODE="${1:-full}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/bootstrap-$TIMESTAMP.log"

if [[ -t 1 ]]; then
    LARRY_COLOR=1
else
    LARRY_COLOR=0
fi
export LARRY_COLOR

mkdir -p "$LOG_DIR"

if [[ "$LARRY_COLOR" == "1" ]]; then
    exec > >(
        tee >(
            sed -E $'s/\x1B\\[[0-9;]*[[:alpha:]]//g' >> "$LOG_FILE"
        )
    ) 2>&1
else
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

# Module paths are resolved dynamically relative to this script.
# shellcheck disable=SC1091
source "$MODULE_DIR/common.sh"
# shellcheck disable=SC1091
source "$MODULE_DIR/packages.sh"
# shellcheck disable=SC1091
source "$MODULE_DIR/apps.sh"
# shellcheck disable=SC1091
source "$MODULE_DIR/ssh.sh"
# shellcheck disable=SC1091
source "$MODULE_DIR/storage.sh"
# shellcheck disable=SC1091
source "$MODULE_DIR/audit.sh"

show_header

case "$MODE" in
    core)
        require_debian
        require_normal_user
        acquire_sudo
        wait_for_package_manager || exit 1
        apt_repair
        configure_multiarch
        configure_debian_repositories
        apt_update_upgrade
        install_core_packages
        configure_mac_keyboard_compatibility
        configure_ssh
        capture_audit
        ;;

    full)
        require_debian
        require_amd64
        require_normal_user
        acquire_sudo
        wait_for_package_manager || exit 1
        apt_repair
        configure_multiarch
        configure_debian_repositories
        apt_update_upgrade
        install_core_packages
        configure_package_defaults
        install_full_packages
        configure_mac_keyboard_compatibility
        configure_xfce_desktop
        configure_flatpak
        install_heroic
        install_vscode
        configure_vscode_codex
        install_codex_cli
        install_1password
        install_spotify
        install_rpi_imager
        install_balena_etcher
        configure_ssh
        configure_local_filesystems
        configure_user_groups
        enable_trim
        safe_package_cleanup
        configure_xfce_panel_layout
        capture_audit
        ;;

    audit)
        capture_audit
        ;;

    *)
        echo "Usage:"
        echo "  $0 core"
        echo "  $0 full"
        echo "  $0 audit"
        exit 2
        ;;
esac

show_application_status
show_summary
