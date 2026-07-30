#!/usr/bin/env bash
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$PROJECT_DIR/modules"
LOG_DIR="$PROJECT_DIR/logs"
MODE="${1:-full}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/bootstrap-$TIMESTAMP.log"

mkdir -p "$LOG_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1

source "$MODULE_DIR/common.sh"
source "$MODULE_DIR/packages.sh"
source "$MODULE_DIR/apps.sh"
source "$MODULE_DIR/ssh.sh"
source "$MODULE_DIR/audit.sh"

show_header

case "$MODE" in
    core)
        require_debian
        require_normal_user
        acquire_sudo
        apt_repair
        configure_multiarch
        apt_update_upgrade
        install_core_packages
        configure_ssh
        capture_audit
        ;;

    full)
        require_debian
        require_normal_user
        acquire_sudo
        apt_repair
        configure_multiarch
        apt_update_upgrade
        install_core_packages
        install_full_packages
        configure_flatpak
        install_heroic
        install_vscode
        install_parsec
        install_1password
        install_spotify
        install_balena_etcher
        configure_ssh
        configure_user_groups
        enable_trim
        safe_package_cleanup
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

show_summary
