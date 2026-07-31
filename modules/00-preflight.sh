#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/preflight-$TIMESTAMP.txt"

mkdir -p "$REPORT_DIR"

log() {
    printf '%-30s %s\n' "$1" "$2" | tee -a "$REPORT_FILE"
}

section() {
    printf '\n%s\n%s\n' "$1" "$(printf '%*s' "${#1}" '' | tr ' ' '=')" \
        | tee -a "$REPORT_FILE"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

failures=0
warnings=0

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
    log "Architecture check" "PASS — Intel Mac"
else
    log "Architecture check" "FAIL — expected x86_64, found $ARCH"
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
    log "macOS version check" "PASS"
else
    log "macOS version check" "WARNING — designed for Monterey or newer"
    warnings=$((warnings + 1))
fi

section "Storage"

ROOT_FREE_KB="$(df -k / | awk 'NR==2 {print $4}')"
ROOT_FREE_GB="$((ROOT_FREE_KB / 1024 / 1024))"
ROOT_USED="$(df -h / | awk 'NR==2 {print $5}')"

log "Root volume used" "$ROOT_USED"
log "Root volume free" "${ROOT_FREE_GB} GB"

if (( ROOT_FREE_GB >= 20 )); then
    log "Disk-space check" "PASS"
elif (( ROOT_FREE_GB >= 10 )); then
    log "Disk-space check" "WARNING — limited free space"
    warnings=$((warnings + 1))
else
    log "Disk-space check" "FAIL — less than 10 GB free"
    failures=$((failures + 1))
fi

section "Required Tools"

if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools" "PASS — $(xcode-select -p)"
else
    log "Xcode Command Line Tools" "FAIL — not installed"
    failures=$((failures + 1))
fi

if command_exists git; then
    log "Git" "PASS — $(git --version)"
else
    log "Git" "FAIL — not installed"
    failures=$((failures + 1))
fi

if command_exists brew; then
    log "Homebrew" "PASS — $(brew --version | head -n 1)"
    log "Homebrew prefix" "$(brew --prefix)"
else
    log "Homebrew" "WARNING — will be installed by the Homebrew module"
    warnings=$((warnings + 1))
fi

section "Security Information"

SIP_STATUS="$(csrutil status 2>&1 || true)"
FILEVAULT_STATUS="$(fdesetup status 2>&1 || true)"
GATEKEEPER_STATUS="$(spctl --status 2>&1 || true)"

if [[ -n "$SIP_STATUS" ]]; then
    while IFS= read -r line; do
        [[ -n "$line" ]] && log "SIP" "$line"
    done <<< "$SIP_STATUS"
else
    log "SIP" "Unable to query"
fi

log "FileVault" "${FILEVAULT_STATUS:-Unable to query}"
log "Gatekeeper" "${GATEKEEPER_STATUS:-Unable to query}"

if [[ "$SIP_STATUS" == *"Custom Configuration"* ]]; then
    log "SIP notice" "WARNING — custom SIP configuration detected"
    warnings=$((warnings + 1))
fi

section "Execution Checks"

if [[ "$(id -u)" -eq 0 ]]; then
    log "Current user check" "FAIL — do not run the bootstrap as root"
    failures=$((failures + 1))
else
    log "Current user check" "PASS"
fi

if [[ -w "$ROOT_DIR" ]]; then
    log "Repository write check" "PASS"
else
    log "Repository write check" "FAIL — repository is not writable"
    failures=$((failures + 1))
fi

section "Preflight Result"

log "Warnings" "$warnings"
log "Blocking failures" "$failures"

if (( failures == 0 )); then
    log "Status" "PASS"
    log "Next stage" "Inventory snapshot"
else
    log "Status" "FAIL"
    printf '\nPreflight failed with %d blocking issue(s).\n' "$failures" >&2
    printf 'Report: %s\n' "$REPORT_FILE" >&2
    exit 1
fi

printf '\nPreflight report: %s\n' "$REPORT_FILE"
