#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=modules/common.sh
source "$ROOT_DIR/modules/common.sh"

REPORT_DIR="$ROOT_DIR/reports"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/filezilla-$TIMESTAMP.txt"
MACBOOK_DRY_RUN="${MACBOOK_DRY_RUN:-0}"

APP_PATH="/Applications/FileZilla.app"
DOWNLOADS_DIR="$HOME/Downloads"

if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    REPORT_FILE="/dev/null"
else
    mkdir -p "$REPORT_DIR"
fi

failures=0
warnings=0
warning_guidance=()

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

filezilla_version() {
    defaults read "$APP_PATH/Contents/Info.plist" \
        CFBundleShortVersionString 2>/dev/null ||
    defaults read "$APP_PATH/Contents/Info" \
        CFBundleShortVersionString 2>/dev/null ||
    echo unknown
}

filezilla_architecture() {
    file "$APP_PATH/Contents/MacOS/filezilla" 2>/dev/null |
        awk -F': ' '{print $2}'
}

verify_filezilla() {
    local version
    local architecture

    if [[ ! -d "$APP_PATH" ]]; then
        report_status fail "FileZilla" "application missing"
        failures=$((failures + 1))
        return 1
    fi

    version="$(filezilla_version)"
    architecture="$(filezilla_architecture)"

    report_status ok "FileZilla" "$version"

    if [[ "$architecture" == *"x86_64"* ]]; then
        report_status ok "Architecture" "x86_64"
    else
        report_status warn "Architecture" "${architecture:-unknown}"
        warning_guidance+=(
            "Architecture|FileZilla is present but is not confirmed as x86_64.|Review compatibility with this Intel Mac."
        )
        warnings=$((warnings + 1))
    fi
}

section "FileZilla Compatibility"

report_status info "Host architecture" "$(uname -m)"

if [[ -d "$APP_PATH" ]]; then
    verify_filezilla
else
    ARCHIVE="$(
        find "$DOWNLOADS_DIR" \
            -maxdepth 1 \
            -type f \
            -iname 'FileZilla_*_macos-x86.app.tar.bz2' \
            -print 2>/dev/null |
            sort |
            tail -n 1
    )"

    if [[ -z "$ARCHIVE" ]]; then
        report_status info "FileZilla" "compatible archive not found"
        report_status info "Expected archive" "FileZilla_*_macos-x86.app.tar.bz2"

        warning_guidance+=(
            "FileZilla|No compatible Intel archive was found in ~/Downloads.|Download a known-good x86_64 FileZilla archive before rerunning."
        )
        warnings=$((warnings + 1))
    else
        if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
            report_status info "FileZilla" "would install"
            report_status info "Archive" "$(basename "$ARCHIVE")"
        else
            TMP_DIR="$(mktemp -d)"
            trap 'rm -rf "$TMP_DIR"' EXIT

            report_status info "Archive" "$(basename "$ARCHIVE")"

            if tar -xjf "$ARCHIVE" -C "$TMP_DIR"; then
            EXTRACTED_APP="$(
                find "$TMP_DIR" \
                    -maxdepth 2 \
                    -type d \
                    -name 'FileZilla.app' \
                    -print \
                    -quit
            )"

            if [[ -z "$EXTRACTED_APP" ]]; then
                report_status fail "Extraction" "FileZilla.app not found"
                failures=$((failures + 1))
            elif sudo ditto "$EXTRACTED_APP" "$APP_PATH"; then
                report_status ok "Installation" "complete"
                verify_filezilla
            else
                report_status fail "Installation" "copy failed"
                failures=$((failures + 1))
            fi
            else
                report_status fail "Extraction" "archive extraction failed"
                failures=$((failures + 1))
            fi
        fi
    fi
fi

if (( ${#warning_guidance[@]} > 0 )); then
    section "Warnings & Actions"

    for item in "${warning_guidance[@]}"; do
        IFS='|' read -r warning_label warning_detail warning_action <<< "$item"

        status_warn
        printf ' %s\n' "$warning_label"
        printf '       %s\n' "$warning_detail"
        printf '       %s\n' "$warning_action"

        {
            printf '[WARN] %s\n' "$warning_label"
            printf '       %s\n' "$warning_detail"
            printf '       %s\n' "$warning_action"
        } >> "$REPORT_FILE"
    done
fi

section "FileZilla Result"

if (( warnings == 0 )); then
    report_status ok "Warnings" "0"
else
    report_status warn "Warnings" "$warnings"
fi

if (( failures == 0 )); then
    report_status ok "Failures" "0"
    report_status ok "Status" "COMPLETE"
else
    report_status fail "Failures" "$failures"
    report_status fail "Status" "INCOMPLETE"
fi

larry_info "FileZilla report: $REPORT_FILE"

exit 0
