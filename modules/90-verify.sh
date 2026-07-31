#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/verify-$TIMESTAMP.txt"

mkdir -p "$REPORT_DIR"

passes=0
warnings=0
failures=0

log() {
    printf '%-32s %s\n' "$1" "$2" | tee -a "$REPORT_FILE"
}

section() {
    printf '\n%s\n%s\n' "$1" "$(printf '%*s' "${#1}" '' | tr ' ' '=')" \
        | tee -a "$REPORT_FILE"
}

pass() {
    log "$1" "PASS — $2"
    passes=$((passes + 1))
}

warn() {
    log "$1" "WARNING — $2"
    warnings=$((warnings + 1))
}

fail() {
    log "$1" "FAIL — $2"
    failures=$((failures + 1))
}

check_command() {
    local command_name="$1"
    local label="$2"

    if command -v "$command_name" >/dev/null 2>&1; then
        pass "$label" "$(command -v "$command_name")"
    else
        fail "$label" "command not found"
    fi
}

check_app() {
    local label="$1"
    shift

    local path

    for path in "$@"; do
        if [[ -d "$path" ]]; then
            pass "$label" "$path"
            return 0
        fi
    done

    fail "$label" "application not found"
    return 1
}

check_optional_app() {
    local label="$1"
    shift

    local path

    for path in "$@"; do
        if [[ -d "$path" ]]; then
            pass "$label" "$path"
            return 0
        fi
    done

    warn "$label" "application not found"
    return 1
}

read_bool_default() {
    local domain="$1"
    local key="$2"

    defaults read "$domain" "$key" 2>/dev/null || echo "unavailable"
}

section "MacBook Bootstrap Verification"

log "Run date" "$(date)"
log "Computer" "$(scutil --get ComputerName 2>/dev/null || hostname)"
log "macOS" "$(sw_vers -productVersion)"
log "Architecture" "$(uname -m)"

section "Core Tools"

check_command brew "Homebrew"
check_command git "Git"
check_command curl "curl"
check_command jq "jq"

if command -v brew >/dev/null 2>&1; then
    pass "Homebrew version" "$(brew --version | head -n 1)"
else
    fail "Homebrew version" "unavailable"
fi

section "Essential Applications"

check_app "Firefox" \
    "/Applications/Firefox.app"

check_app "Chromium" \
    "/Applications/Chromium.app"

check_app "Visual Studio Code" \
    "/Applications/Visual Studio Code.app"

check_app "1Password" \
    "/Applications/1Password.app"

check_app "ChatGPT-Left75" \
    "/Applications/chatgpt-left75.app" \
    "/Applications/ChatGPT-Left75.app"

section "Daily Applications"

check_optional_app "Spotify" \
    "/Applications/Spotify.app"

check_optional_app "VLC" \
    "/Applications/VLC.app"

check_optional_app "FileZilla" \
    "/Applications/FileZilla.app"

check_optional_app "Rectangle" \
    "/Applications/Rectangle.app"

check_optional_app "Keka" \
    "/Applications/Keka.app"

check_optional_app "Stats" \
    "/Applications/Stats.app"

check_optional_app "Amphetamine" \
    "/Applications/Amphetamine.app"

check_optional_app "Moonlight" \
    "/Applications/Moonlight.app"

section "Homelab and Media Applications"

check_optional_app "Wireshark" \
    "/Applications/Wireshark.app"

check_optional_app "Raspberry Pi Imager" \
    "/Applications/Raspberry Pi Imager.app"

check_optional_app "Balena Etcher" \
    "/Applications/balenaEtcher.app" \
    "/Applications/BalenaEtcher.app"

check_optional_app "Private Internet Access" \
    "/Applications/Private Internet Access.app"

check_optional_app "HandBrake" \
    "/Applications/HandBrake.app"

check_optional_app "MKVToolNix" \
    "/Applications/MKVToolNix-*.app" \
    "/Applications/MKVToolNix.app"

check_optional_app "MakeMKV" \
    "/Applications/MakeMKV.app"

section "Developer Environment"

if command -v rustc >/dev/null 2>&1; then
    pass "Rust" "$(rustc --version)"
else
    warn "Rust" "not installed"
fi

if command -v cargo >/dev/null 2>&1; then
    pass "Cargo" "$(cargo --version)"
else
    warn "Cargo" "not installed"
fi

if command -v cargo-tauri >/dev/null 2>&1; then
    pass "Tauri CLI" "$(cargo-tauri --version 2>/dev/null || echo installed)"
elif command -v cargo >/dev/null 2>&1 && cargo tauri --version >/dev/null 2>&1; then
    pass "Tauri CLI" "$(cargo tauri --version)"
else
    warn "Tauri CLI" "not installed"
fi

if command -v node >/dev/null 2>&1; then
    pass "Node.js" "$(node --version)"
else
    warn "Node.js" "not installed"
fi

section "macOS Preferences"

finder_extensions="$(read_bool_default NSGlobalDomain AppleShowAllExtensions)"
finder_pathbar="$(read_bool_default com.apple.finder ShowPathbar)"
finder_statusbar="$(read_bool_default com.apple.finder ShowStatusBar)"
dock_autohide="$(read_bool_default com.apple.dock autohide)"
dock_recents="$(read_bool_default com.apple.dock show-recents)"
tap_to_click="$(read_bool_default com.apple.AppleMultitouchTrackpad Clicking)"
reduce_motion="$(read_bool_default com.apple.universalaccess reduceMotion)"
reduce_transparency="$(read_bool_default com.apple.universalaccess reduceTransparency)"

[[ "$finder_extensions" == "1" ]] \
    && pass "Finder extensions" "enabled" \
    || fail "Finder extensions" "expected enabled, found $finder_extensions"

[[ "$finder_pathbar" == "1" ]] \
    && pass "Finder path bar" "enabled" \
    || fail "Finder path bar" "expected enabled, found $finder_pathbar"

[[ "$finder_statusbar" == "1" ]] \
    && pass "Finder status bar" "enabled" \
    || fail "Finder status bar" "expected enabled, found $finder_statusbar"

[[ "$dock_autohide" == "1" ]] \
    && pass "Dock auto-hide" "enabled" \
    || fail "Dock auto-hide" "expected enabled, found $dock_autohide"

[[ "$dock_recents" == "0" ]] \
    && pass "Dock recent apps" "disabled" \
    || fail "Dock recent apps" "expected disabled, found $dock_recents"

[[ "$tap_to_click" == "1" ]] \
    && pass "Tap to click" "enabled" \
    || warn "Tap to click" "expected enabled, found $tap_to_click"

[[ "$reduce_motion" == "1" ]] \
    && pass "Reduce motion" "enabled" \
    || warn "Reduce motion" "expected enabled, found $reduce_motion"

[[ "$reduce_transparency" == "1" ]] \
    && pass "Reduce transparency" "enabled" \
    || warn "Reduce transparency" "expected enabled, found $reduce_transparency"

SCREENSHOT_FOLDER="$HOME/Pictures/Screenshots"

if [[ -d "$SCREENSHOT_FOLDER" ]]; then
    pass "Screenshot folder" "$SCREENSHOT_FOLDER"
else
    fail "Screenshot folder" "missing"
fi

section "Custom ChatGPT Application"

CHATGPT_APP=""

for candidate in \
    "/Applications/chatgpt-left75.app" \
    "/Applications/ChatGPT-Left75.app"
do
    if [[ -d "$candidate" ]]; then
        CHATGPT_APP="$candidate"
        break
    fi
done

if [[ -n "$CHATGPT_APP" ]]; then
    bundle_id="$(
        defaults read "$CHATGPT_APP/Contents/Info" CFBundleIdentifier \
            2>/dev/null || echo unknown
    )"

    app_version="$(
        defaults read "$CHATGPT_APP/Contents/Info" CFBundleShortVersionString \
            2>/dev/null || echo unknown
    )"

    [[ "$bundle_id" == "com.matthewjordan.chatgpt-left75" ]] \
        && pass "ChatGPT bundle ID" "$bundle_id" \
        || warn "ChatGPT bundle ID" "$bundle_id"

    pass "ChatGPT version" "$app_version"
else
    fail "ChatGPT metadata" "application missing"
fi

section "Verification Result"

total=$((passes + warnings + failures))

log "Checks performed" "$total"
log "Passed" "$passes"
log "Warnings" "$warnings"
log "Failures" "$failures"

if (( failures == 0 )); then
    log "Overall status" "PASS"
else
    log "Overall status" "INCOMPLETE"
fi

log "Report" "$REPORT_FILE"

printf '\nVerification report: %s\n' "$REPORT_FILE"

exit 0
