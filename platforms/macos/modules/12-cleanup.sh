#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=modules/common.sh
source "$ROOT_DIR/modules/common.sh"

REPORT_DIR="$ROOT_DIR/reports"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/cleanup-$TIMESTAMP.txt"
MACBOOK_DRY_RUN="${MACBOOK_DRY_RUN:-0}"

if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    REPORT_FILE="/dev/null"
else
    mkdir -p "$REPORT_DIR"
fi

removed_count=0
present_count=0
failed_count=0

section() {
    local title="$1"

    larry_section "$title"

    {
        printf '\n%s\n' "$title"
        printf '%*s\n' "${#title}" '' | tr ' ' '='
    } >> "$REPORT_FILE"
}

report_status() {
    local level="$1"
    local label="$2"
    local message="$3"
    local marker

    case "$level" in
        ok)   marker="[ OK ]" ;;
        warn) marker="[WARN]" ;;
        fail) marker="[FAIL]" ;;
        info) marker="[INFO]" ;;
        *)    marker="[????]" ;;
    esac

    printf '%-24s %-43.43s ' "$label" "$message"

    case "$level" in
        ok)   status_ok ;;
        warn) status_warn ;;
        fail) status_fail ;;
        info) status_info ;;
        *)    printf '%s' "$marker" ;;
    esac

    printf '\n'

    printf '%-24s %-43s %s\n' \
        "$label" "$message" "$marker" >> "$REPORT_FILE"
}

section "Retired Application Cleanup"

if [[ -d /Applications/Parsec.app ]]; then
    if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
        report_status info "Parsec application" "would remove"
    else
        pkill -x Parsec 2>/dev/null || true

        if sudo rm -rf /Applications/Parsec.app; then
            report_status ok "Parsec application" "removed"
            removed_count=$((removed_count + 1))
        else
            report_status fail "Parsec application" "could not remove"
            failed_count=$((failed_count + 1))
        fi
    fi
else
    report_status ok "Parsec application" "not present"
    present_count=$((present_count + 1))
fi

parsec_user_items=(
    "$HOME/Library/Preferences/tv.parsec.www.plist"
    "$HOME/Library/Caches/tv.parsec.www"
)

parsec_user_found=0

for item in "${parsec_user_items[@]}"; do
    if [[ -e "$item" ]]; then
        parsec_user_found=1

        if [[ "$MACBOOK_DRY_RUN" != "1" ]]; then
            rm -rf "$item"
        fi
    fi
done

if (( parsec_user_found == 1 )); then
    if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
        report_status info "Parsec user data" "would remove"
    elif [[ ! -e "$HOME/Library/Preferences/tv.parsec.www.plist" &&
            ! -e "$HOME/Library/Caches/tv.parsec.www" ]]; then
        report_status ok "Parsec user data" "removed"
        removed_count=$((removed_count + 1))
    else
        report_status fail "Parsec user data" "remnants remain"
        failed_count=$((failed_count + 1))
    fi
else
    report_status ok "Parsec user data" "not present"
    present_count=$((present_count + 1))
fi

# Apple's parsecd service is unrelated to Parsec remote desktop.
if [[ -e "$HOME/Library/Preferences/com.apple.parsecd.plist" ||
      -e "$HOME/Library/Caches/com.apple.parsecd" ]]; then
    report_status info "Apple parsecd" "preserved"
else
    report_status info "Apple parsecd" "not present"
fi

section "Cleanup Result"

report_status info "Already clean" "$present_count"
report_status info "Removed" "$removed_count"

if (( failed_count == 0 )); then
    report_status ok "Failures" "0"
    report_status ok "Status" "COMPLETE"
else
    report_status fail "Failures" "$failed_count"
    report_status fail "Status" "INCOMPLETE"
fi

larry_info "Cleanup report: $REPORT_FILE"

exit 0
