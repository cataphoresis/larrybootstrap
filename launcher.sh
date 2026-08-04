#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" == "${BASH_SOURCE[0]}" ]] && SCRIPT_DIR="."
ROOT_DIR="$(cd "$SCRIPT_DIR" && pwd)"
ACTION="menu"
PROFILE="standard"

usage() {
    printf '%s\n' \
        'Usage: ./launcher.sh [--action menu|install|verify|audit|reports] [--profile NAME]' \
        '' \
        'With no arguments, LarryLauncher starts its interactive BBS-style menu.'
}

while (( $# > 0 )); do
    case "$1" in
        --action)
            [[ $# -ge 2 ]] || { printf '[FAIL] --action requires a value.\n' >&2; exit 2; }
            ACTION="$2"
            shift 2
            ;;
        --profile)
            [[ $# -ge 2 ]] || { printf '[FAIL] --profile requires a value.\n' >&2; exit 2; }
            PROFILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf '[FAIL] Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "$(uname -s)" in
    Darwin)
        PLATFORM="macOS"
        BOOTSTRAP="$ROOT_DIR/bootstrap.sh"
        REPORT_DIR="$ROOT_DIR/platforms/macos/reports"
        ;;
    Linux)
        PLATFORM="Linux"
        BOOTSTRAP="$ROOT_DIR/bootstrap.sh"
        REPORT_DIR="$ROOT_DIR/platforms/linux/reports"
        ;;
    *)
        printf '[FAIL] LarryLauncher does not support this operating system.\n' >&2
        exit 1
        ;;
esac

show_banner() {
    printf '\n+----------------------------------------------------------+\n'
    printf '|  L A R R Y L A U N C H E R  //  NODE ONLINE            |\n'
    printf '+----------------------------------------------------------+\n'
    printf '|  SYSTEM  %-18s PROFILE  %-17s|\n' "$PLATFORM" "$PROFILE"
    printf '|  USER    %-19s HOST     %-17s|\n' "$(id -un)" "$(hostname -s)"
    printf '+----------------------------------------------------------+\n'
}

connection_effect() {
    [[ "${LARRY_ANIMATE:-0}" == "1" && -t 1 ]] || return 0
    local stage
    for stage in 'DIALING NODE' 'NEGOTIATING 9600 BAUD' 'AUTHENTICATING OPERATOR'; do
        printf '%-28s' "$stage"
        for _ in 1 2 3; do
            sleep 0.22
            printf '.'
        done
        printf ' OK\n'
    done
    printf 'CARRIER DETECTED // LARRYLINK ONLINE\n'
}

show_reports() {
    printf '\nRecent Reports\n==============\n'
    if [[ ! -d "$REPORT_DIR" ]]; then
        printf '[INFO] No report directory exists yet.\n'
        return 0
    fi

    local found=false
    while IFS= read -r report; do
        [[ -n "$report" ]] || continue
        found=true
        printf '[INFO] %s\n' "$report"
    done < <(find "$REPORT_DIR" -maxdepth 2 -type f -print 2>/dev/null | sort -r | head -n 10)

    [[ "$found" == true ]] || printf '[INFO] No reports have been generated yet.\n'
    printf '[INFO] %s\n' "$REPORT_DIR"
}

run_action() {
    local selected="$1"

    case "$selected" in
        install)
            if [[ "$PLATFORM" == "macOS" ]]; then
                "$BOOTSTRAP" --profile "$PROFILE"
            else
                "$BOOTSTRAP" full
            fi
            ;;
        verify|audit)
            if [[ "$PLATFORM" == "macOS" ]]; then
                "$BOOTSTRAP" --profile "$PROFILE" --verify-only
            else
                "$BOOTSTRAP" audit
            fi
            ;;
        reports)
            show_reports
            ;;
        exit)
            return 0
            ;;
        *)
            printf '[FAIL] Unsupported action: %s\n' "$selected" >&2
            return 2
            ;;
    esac
}

show_banner
connection_effect

if [[ "$ACTION" != "menu" ]]; then
    run_action "$ACTION"
    exit $?
fi

while true; do
    printf '\n[1] Install / reconcile workstation\n'
    printf '[2] Verify configuration\n'
    printf '[3] Run system audit\n'
    printf '[4] List recent reports\n'
    printf '[Q] Disconnect\n\n'
    read -r -p 'SELECT: ' selection

    case "$selection" in
        1)
            read -r -p 'Run the full bootstrap? [y/N] ' confirmation
            [[ "$confirmation" =~ ^[Yy]$ ]] || { printf '[INFO] Install cancelled.\n'; continue; }
            selected_action="install"
            ;;
        2) selected_action="verify" ;;
        3) selected_action="audit" ;;
        4) selected_action="reports" ;;
        q|Q)
            printf '[INFO] Carrier dropped. Goodbye.\n'
            exit 0
            ;;
        *)
            printf '[WARN] Unknown selection.\n'
            continue
            ;;
    esac

    if run_action "$selected_action"; then
        printf '[INFO] Action finished successfully.\n'
    else
        code=$?
        printf '[WARN] Action finished with exit code %d.\n' "$code"
    fi
done
