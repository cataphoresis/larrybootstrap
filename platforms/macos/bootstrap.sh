#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=modules/common.sh
source "$ROOT_DIR/modules/common.sh"

PROFILE="standard"
VERIFY_ONLY=false
MACBOOK_DRY_RUN="${MACBOOK_DRY_RUN:-0}"

usage() {
    cat <<USAGE
Usage:
  ./bootstrap.sh [options]

Options:
  --profile NAME   Package profile: minimal, standard, developer
                   Default: standard
  --verify-only    Run only the verification module
  --dry-run        Inspect and report without changing machine state
  -h, --help       Show this help

Examples:
  ./bootstrap.sh
  ./bootstrap.sh --profile developer
  ./bootstrap.sh --verify-only
USAGE
}

while (( $# > 0 )); do
    case "$1" in
        --profile)
            [[ $# -ge 2 ]] || {
                larry_fail "--profile requires a value."
                exit 1
            }

            PROFILE="$2"
            shift 2
            ;;

        --verify-only)
            VERIFY_ONLY=true
            shift
            ;;

        --dry-run)
            MACBOOK_DRY_RUN=1
            shift
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            larry_fail "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

PROFILE_FILE="$ROOT_DIR/profiles/$PROFILE.conf"

if [[ "$VERIFY_ONLY" == false && ! -f "$PROFILE_FILE" ]]; then
    larry_fail "Unknown profile: $PROFILE"
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
        larry_fail "Missing or non-executable module: $path"
        exit 1
    fi

    larry_section "Running $module"

    MACBOOK_DRY_RUN="$MACBOOK_DRY_RUN" "$path"
}

larry_section "MacBook Bootstrap"

printf 'Profile: %s\n' "$PROFILE"
printf 'User:    %s\n' "$(id -un)"
printf 'Host:    %s\n' "$(scutil --get ComputerName 2>/dev/null || hostname)"
printf 'macOS:   %s\n' "$(sw_vers -productVersion)"
printf 'Arch:    %s\n' "$(uname -m)"
printf 'Started: %s\n' "$(date)"
[[ "$MACBOOK_DRY_RUN" == "1" ]] && printf 'Mode:    DRY RUN — no machine-state changes\n'

if [[ "$VERIFY_ONLY" == true ]]; then
    run_module "90-verify.sh"
    exit 0
fi

export MACBOOK_PROFILE="$PROFILE"

MODULES=(
    "00-preflight.sh"
    "01-inventory.sh"
    "10-homebrew.sh"
    "12-cleanup.sh"
    "15-compat-tools.sh"
    "20-defaults.sh"
    "25-filezilla.sh"
    "90-verify.sh"
)

for module in "${MODULES[@]}"; do
    run_module "$module"
done

larry_section "Bootstrap complete"

larry_ok "Bootstrap sequence completed"
larry_info "Profile:  $PROFILE"
larry_info "Finished: $(date)"
larry_info "Reports:  $ROOT_DIR/reports"
