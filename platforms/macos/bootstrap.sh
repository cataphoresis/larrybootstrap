#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="standard"
VERIFY_ONLY=false

usage() {
    cat <<USAGE
Usage:
  ./bootstrap.sh [options]

Options:
  --profile NAME   Package profile: minimal, standard, homelab, developer
                   Default: standard
  --verify-only    Run only the verification module
  -h, --help       Show this help

Examples:
  ./bootstrap.sh
  ./bootstrap.sh --profile homelab
  ./bootstrap.sh --verify-only
USAGE
}

while (( $# > 0 )); do
    case "$1" in
        --profile)
            [[ $# -ge 2 ]] || {
                echo "ERROR: --profile requires a value." >&2
                exit 1
            }

            PROFILE="$2"
            shift 2
            ;;

        --verify-only)
            VERIFY_ONLY=true
            shift
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            echo "ERROR: Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

PROFILE_FILE="$ROOT_DIR/profiles/$PROFILE.conf"

if [[ "$VERIFY_ONLY" == false && ! -f "$PROFILE_FILE" ]]; then
    echo "ERROR: Unknown profile: $PROFILE" >&2
    echo
    echo "Available profiles:"

    find "$ROOT_DIR/profiles" \
        -maxdepth 1 \
        -type f \
        -name '*.conf' \
        -exec basename {} .conf \; \
        | sort \
        | sed 's/^/  /'

    exit 1
fi

run_module() {
    local module="$1"
    local path="$ROOT_DIR/modules/$module"

    if [[ ! -x "$path" ]]; then
        echo "ERROR: Missing or non-executable module: $path" >&2
        exit 1
    fi

    printf '\n============================================================\n'
    printf ' Running %s\n' "$module"
    printf '============================================================\n'

    "$path"
}

show_banner() {
    printf '\n============================================================\n'
    printf ' macOS Bootstrap\n'
    printf '============================================================\n'
    printf 'Profile:    %s\n' "$PROFILE"
    printf 'User:       %s\n' "$(id -un)"
    printf 'Computer:   %s\n' "$(hostname -s)"
    printf 'System:     macOS %s\n' "$(sw_vers -productVersion)"
    printf 'Shell:      Bash %s\n' "$BASH_VERSION"
    printf 'Started:    %s\n' "$(date)"
}

show_banner

if [[ "$VERIFY_ONLY" == true ]]; then
    run_module "90-verify.sh"
    exit 0
fi

export MACBOOK_PROFILE="$PROFILE"

MODULES=(
    "00-preflight.sh"
    "01-inventory.sh"
    "10-homebrew.sh"
    "20-defaults.sh"
    "25-filezilla.sh"
    "90-verify.sh"
)

for module in "${MODULES[@]}"; do
    run_module "$module"
done

printf '\n============================================================\n'
printf ' Bootstrap complete\n'
printf '============================================================\n'
printf 'Profile:  %s\n' "$PROFILE"
printf 'Finished: %s\n' "$(date)"
printf 'Reports:  %s\n' "$ROOT_DIR/reports"
