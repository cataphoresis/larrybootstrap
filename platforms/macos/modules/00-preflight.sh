#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=modules/common.sh
source "$ROOT_DIR/modules/common.sh"

REPORT_DIR="$ROOT_DIR/reports"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/preflight-$TIMESTAMP.txt"
MACBOOK_DRY_RUN="${MACBOOK_DRY_RUN:-0}"

if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    REPORT_FILE="/dev/null"
else
    mkdir -p "$REPORT_DIR"
fi

log() {
    local label="$1"
    local message="$2"

    printf '%-24s %s\n' "$label" "$message"
    printf '%-24s %s\n' "$label" "$message" >> "$REPORT_FILE"
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
section() {
    local title="$1"

    larry_section "$title"

    {
        printf '\n%s\n' "$title"
        printf '%*s\n' "${#title}" '' | tr ' ' '='
    } >> "$REPORT_FILE"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

failures=0
warnings=0
warning_guidance=()

section "MacBook Bootstrap Preflight"

log "Run date" "$(date)"
log "Computer name" "$(scutil --get ComputerName 2>/dev/null || hostname)"
log "Hostname" "$(hostname)"
log "Current user" "$(id -un)"
log "User ID" "$(id -u)"
log "Shell" "${SHELL:-unknown}"

section "Hardware"

MODEL_IDENTIFIER="$(
    system_profiler SPHardwareDataType 2>/dev/null |
        awk -F': ' '/Model Identifier/ {print $2; exit}'
)"

MODEL_NAME="$(
    system_profiler SPHardwareDataType 2>/dev/null |
        awk -F': ' '/Model Name/ {print $2; exit}'
)"

MEMORY="$(
    system_profiler SPHardwareDataType 2>/dev/null |
        awk -F': ' '/Memory/ {print $2; exit}'
)"

ARCH="$(uname -m)"
CPU="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"

log "Model name" "${MODEL_NAME:-unknown}"
log "Model identifier" "${MODEL_IDENTIFIER:-unknown}"
log "Architecture" "$ARCH"
log "Processor" "$CPU"
log "Memory" "${MEMORY:-unknown}"

if [[ "$ARCH" == "x86_64" ]]; then
    report_status ok "Architecture check" "Intel Mac"
else
    report_status fail "Architecture check" "expected x86_64, found $ARCH"
    failures=$((failures + 1))
fi

section "macOS"

MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_BUILD="$(sw_vers -buildVersion)"
MACOS_NAME="$(sw_vers -productName)"

log "Operating system" "$MACOS_NAME"
log "Version" "$MACOS_VERSION"
log "Build" "$MACOS_BUILD"

MACOS_MAJOR="${MACOS_VERSION%%.*}"

if (( MACOS_MAJOR >= 12 )); then
    report_status ok "macOS version check" "$MACOS_VERSION"
else
    report_status warn "macOS version check" "designed for Monterey or newer"
    warnings=$((warnings + 1))
fi

section "Storage"

ROOT_FREE_KB="$(df -k / | awk 'NR==2 {print $4}')"
ROOT_FREE_GB="$((ROOT_FREE_KB / 1024 / 1024))"
ROOT_USED="$(df -h / | awk 'NR==2 {print $5}')"

log "Root volume used" "$ROOT_USED"
log "Root volume free" "${ROOT_FREE_GB} GB"

if (( ROOT_FREE_GB >= 20 )); then
    report_status ok "Disk-space check" "${ROOT_FREE_GB} GB free"
elif (( ROOT_FREE_GB >= 10 )); then
    report_status warn "Disk-space check" "${ROOT_FREE_GB} GB free"
    warnings=$((warnings + 1))
else
    report_status fail "Disk-space check" "less than 10 GB free"
    failures=$((failures + 1))
fi

section "Required Tools"

if xcode-select -p >/dev/null 2>&1; then
    report_status ok "Xcode Command Line Tools" "$(xcode-select -p)"
else
    report_status fail "Xcode Command Line Tools" "not installed"
    failures=$((failures + 1))
fi

if command_exists git; then
    report_status ok "Git" "$(git --version)"
else
    report_status fail "Git" "not installed"
    failures=$((failures + 1))
fi

if command_exists brew; then
    report_status ok "Homebrew" "$(brew --version | head -n 1)"
    log "Homebrew prefix" "$(brew --prefix)"
else
    report_status warn "Homebrew" "will be installed by Homebrew module"
    warnings=$((warnings + 1))
fi

section "Security Information"

SIP_STATUS="$(csrutil status 2>&1 || true)"
FILEVAULT_STATUS="$(fdesetup status 2>&1 || true)"
GATEKEEPER_STATUS="$(spctl --status 2>&1 || true)"

{
    printf '=== SIP ===\n%s\n\n' "$SIP_STATUS"
    printf '=== FileVault ===\n%s\n\n' "$FILEVAULT_STATUS"
    printf '=== Gatekeeper ===\n%s\n' "$GATEKEEPER_STATUS"
} >> "$REPORT_FILE"

if [[ "$SIP_STATUS" == *"Custom Configuration"* ]]; then
    report_status warn \
        "SIP configuration" \
        "Custom Configuration"

    warning_guidance+=(
        "SIP configuration|Nonstandard SIP settings detected.|Review: leave unchanged unless specifically required."
    )

    warnings=$((warnings + 1))
elif [[ "$SIP_STATUS" == *"enabled"* ]]; then
    report_status ok \
        "SIP configuration" \
        "Enabled"
elif [[ "$SIP_STATUS" == *"disabled"* ]]; then
    report_status warn \
        "SIP configuration" \
        "Disabled"
    warnings=$((warnings + 1))
else
    report_status warn \
        "SIP configuration" \
        "Unknown"
    warnings=$((warnings + 1))
fi

if [[ "$FILEVAULT_STATUS" == *"FileVault is On"* ]]; then
    report_status ok "FileVault" "On"
elif [[ "$FILEVAULT_STATUS" == *"FileVault is Off"* ]]; then
    report_status info "FileVault" "Off"
else
    report_status warn "FileVault" "Unknown"
    warnings=$((warnings + 1))
fi

if [[ "$GATEKEEPER_STATUS" == *"assessments enabled"* ]]; then
    report_status ok "Gatekeeper" "Enabled"
else
    report_status warn "Gatekeeper" "Disabled or unknown"
    warnings=$((warnings + 1))
fi

section "Execution Checks"

if [[ "$(id -u)" -eq 0 ]]; then
    report_status fail "Current user check" "do not run bootstrap as root"
    failures=$((failures + 1))
else
    report_status ok "Current user check" "$(id -un)"
fi

if [[ -w "$ROOT_DIR" ]]; then
    report_status ok "Repository write check" "writable"
else
    report_status fail "Repository write check" "repository is not writable"
    failures=$((failures + 1))
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

section "Preflight Result"

if (( warnings == 0 )); then
    report_status ok "Warnings" "0"
else
    report_status warn "Warnings" "$warnings"
fi

if (( failures == 0 )); then
    report_status ok "Blocking failures" "0"
    report_status ok "Status" "PASS"
    report_status info "Next stage" "Inventory snapshot"
else
    report_status fail "Blocking failures" "$failures"
    report_status fail "Status" "FAIL"
    larry_fail "Preflight failed with $failures blocking issue(s)"
    larry_info "Report: $REPORT_FILE"
    exit 1
fi

larry_info "Preflight report: $REPORT_FILE"
