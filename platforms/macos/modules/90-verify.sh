#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=modules/common.sh
source "$ROOT_DIR/modules/common.sh"

REPORT_DIR="$ROOT_DIR/reports"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/verify-$TIMESTAMP.txt"
MACBOOK_DRY_RUN="${MACBOOK_DRY_RUN:-0}"

PROFILE="${MACBOOK_PROFILE:-standard}"
PROFILE_FILE="$ROOT_DIR/profiles/$PROFILE.conf"

if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    REPORT_FILE="/dev/null"
else
    mkdir -p "$REPORT_DIR"
fi

passes=0
warnings=0
failures=0
warning_guidance=()
failure_guidance=()

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

pass() {
    report_status ok "$1" "$2"
    passes=$((passes + 1))
}

warn() {
    local label="$1"
    local message="$2"
    local action="${3:-Review this item if the missing functionality is needed.}"

    report_status warn "$label" "$message"
    warning_guidance+=("$label|$message|$action")
    warnings=$((warnings + 1))
}

fail() {
    local label="$1"
    local message="$2"
    local action="${3:-Correct this issue and rerun verification.}"

    report_status fail "$label" "$message"
    failure_guidance+=("$label|$message|$action")
    failures=$((failures + 1))
}

command_version() {
    local command_name="$1"

    case "$command_name" in
        brew)
            brew --version 2>/dev/null | head -n 1
            ;;
        git)
            git --version 2>/dev/null
            ;;
        gh)
            gh --version 2>/dev/null | head -n 1
            ;;
        jq)
            jq --version 2>/dev/null
            ;;
        wget)
            wget --version 2>/dev/null |
                awk 'NR == 1 {print $3; exit}'
            ;;
        ffmpeg)
            ffmpeg -version 2>/dev/null |
                awk 'NR == 1 {print $3; exit}'
            ;;
        ffprobe)
            ffprobe -version 2>/dev/null |
                awk 'NR == 1 {print $3; exit}'
            ;;
        yt-dlp)
            yt-dlp --version 2>/dev/null | head -n 1
            ;;
        *)
            "$command_name" --version 2>/dev/null | head -n 1
            ;;
    esac
}

check_command() {
    local command_name="$1"
    local label="$2"

    if command -v "$command_name" >/dev/null 2>&1; then
        pass "$label" "$(command_version "$command_name")"
    else
        fail \
            "$label" \
            "command not found" \
            "Install or restore $command_name, then rerun verification."
    fi
}

app_version() {
    local app_path="$1"
    local version=""

    version="$(
        defaults read "$app_path/Contents/Info.plist" \
            CFBundleShortVersionString 2>/dev/null ||
        defaults read "$app_path/Contents/Info" \
            CFBundleShortVersionString 2>/dev/null ||
        true
    )"

    printf '%s\n' "${version:-installed}"
}

check_app() {
    local label="$1"
    shift

    local app_path

    for app_path in "$@"; do
        if [[ -d "$app_path" ]]; then
            pass "$label" "$(app_version "$app_path")"
            return 0
        fi
    done

    fail \
        "$label" \
        "application not found" \
        "Install $label and rerun verification."

    return 1
}

check_optional_app() {
    local label="$1"
    shift

    local app_path

    for app_path in "$@"; do
        if [[ -d "$app_path" ]]; then
            pass "$label" "$(app_version "$app_path")"
            return 0
        fi
    done

    warn \
        "$label" \
        "application not found" \
        "Install $label if this optional capability is desired."

    return 1
}

read_default() {
    defaults read "$1" "$2" 2>/dev/null || echo unavailable
}

verify_default() {
    local domain="$1"
    local key="$2"
    local expected="$3"
    local label="$4"
    local display="$5"
    local actual

    actual="$(read_default "$domain" "$key")"

    if [[ "$actual" == "$expected" ]]; then
        pass "$label" "$display"
    else
        fail \
            "$label" \
            "expected $expected; found $actual" \
            "Rerun the defaults module and verify the setting."
    fi
}

section "MacBook Bootstrap Verification"

report_status info "Profile" "$PROFILE"
report_status info "Computer" "$(scutil --get ComputerName 2>/dev/null || hostname)"
report_status info "macOS" "$(sw_vers -productVersion)"
report_status info "Architecture" "$(uname -m)"

if [[ ! -f "$PROFILE_FILE" ]]; then
    fail \
        "Profile" \
        "unknown profile: $PROFILE" \
        "Select minimal, standard, or developer."
else
    # shellcheck disable=SC1090
    source "$PROFILE_FILE"
fi

section "Core Tools"

check_command brew "Homebrew"
check_command git "Git"
check_command gh "GitHub CLI"
check_command curl "curl"
check_command jq "jq"

if [[ "$PROFILE" != "minimal" ]]; then
    check_command wget "wget"
fi

section "Compatibility Tools"

check_command ffmpeg "ffmpeg"
check_command ffprobe "ffprobe"
check_command yt-dlp "yt-dlp"

section "Essential Applications"

check_app \
    "Firefox" \
    "/Applications/Firefox.app"

check_app \
    "Visual Studio Code" \
    "/Applications/Visual Studio Code.app"

check_app \
    "1Password" \
    "/Applications/1Password.app"

check_app \
    "ChatGPT-Left75" \
    "/Applications/chatgpt-left75.app" \
    "/Applications/ChatGPT-Left75.app"

section "Standard Applications"

check_app \
    "Spotify" \
    "/Applications/Spotify.app"

check_app \
    "VLC" \
    "/Applications/VLC.app"

check_app \
    "Rectangle" \
    "/Applications/Rectangle.app"

check_app \
    "Keka" \
    "/Applications/Keka.app"

check_app \
    "Stats" \
    "/Applications/Stats.app"

check_app \
    "Moonlight" \
    "/Applications/Moonlight.app"

check_app \
    "FileZilla" \
    "/Applications/FileZilla.app"

check_app \
    "Private Internet Access" \
    "/Applications/Private Internet Access.app"

section "Manual Application State"

if [[ -d "/Applications/Amphetamine.app" ]]; then
    pass "Amphetamine" "$(app_version "/Applications/Amphetamine.app")"
else
    report_status info "Amphetamine" "manual/App Store install pending"
fi

section "Retired Applications"

if [[ ! -d "/Applications/Parsec.app" ]]; then
    pass "Parsec" "removed"
else
    fail \
        "Parsec" \
        "retired application still installed" \
        "Run modules/12-cleanup.sh."
fi

if [[ ! -e "$HOME/Library/Preferences/tv.parsec.www.plist" &&
      ! -e "$HOME/Library/Caches/tv.parsec.www" ]]; then
    pass "Parsec user data" "removed"
else
    fail \
        "Parsec user data" \
        "retired remnants remain" \
        "Run modules/12-cleanup.sh."
fi

if [[ "$PROFILE" == "developer" ]]; then
    section "Developer Environment"

    check_command node "Node.js"
    check_command python3 "Python"
    check_command cmake "CMake"
    check_command pkg-config "pkg-config"

    if command -v rustc >/dev/null 2>&1; then
        pass "Rust" "$(rustc --version)"
    else
        warn \
            "Rust" \
            "not installed" \
            "Install rustup if Rust/Tauri development is required."
    fi

    if command -v cargo >/dev/null 2>&1; then
        pass "Cargo" "$(cargo --version)"
    else
        warn \
            "Cargo" \
            "not installed" \
            "Install rustup if Rust/Tauri development is required."
    fi

    if command -v cargo-tauri >/dev/null 2>&1; then
        pass "Tauri CLI" "$(cargo-tauri --version 2>/dev/null || echo installed)"
    elif command -v cargo >/dev/null 2>&1 &&
         cargo tauri --version >/dev/null 2>&1; then
        pass "Tauri CLI" "$(cargo tauri --version)"
    else
        warn \
            "Tauri CLI" \
            "not installed" \
            "Install the Tauri CLI if ChatGPT-Left75 development is required."
    fi

    section "Developer / Extended Applications"

    check_optional_app \
        "Wireshark" \
        "/Applications/Wireshark.app"

    check_optional_app \
        "Raspberry Pi Imager" \
        "/Applications/Raspberry Pi Imager.app"

    check_optional_app \
        "Balena Etcher" \
        "/Applications/balenaEtcher.app" \
        "/Applications/BalenaEtcher.app"

    check_optional_app \
        "HandBrake" \
        "/Applications/HandBrake.app"

    check_optional_app \
        "MKVToolNix" \
        "/Applications/MKVToolNix.app"

    check_optional_app \
        "MakeMKV" \
        "/Applications/MakeMKV.app"
fi

section "macOS Preferences"

verify_default \
    NSGlobalDomain AppleShowAllExtensions 1 \
    "Finder extensions" "enabled"

verify_default \
    com.apple.finder ShowPathbar 1 \
    "Finder path bar" "enabled"

verify_default \
    com.apple.finder ShowStatusBar 1 \
    "Finder status bar" "enabled"

verify_default \
    com.apple.dock autohide 1 \
    "Dock auto-hide" "enabled"

verify_default \
    com.apple.dock show-recents 0 \
    "Dock recent apps" "disabled"

verify_default \
    com.apple.AppleMultitouchTrackpad Clicking 1 \
    "Tap to click" "enabled"

verify_default \
    com.apple.universalaccess reduceMotion 1 \
    "Reduce motion" "enabled"

verify_default \
    com.apple.universalaccess reduceTransparency 1 \
    "Reduce transparency" "enabled"

if [[ -d "$HOME/Pictures/Screenshots" ]]; then
    pass "Screenshot folder" "~/Pictures/Screenshots"
else
    fail \
        "Screenshot folder" \
        "missing" \
        "Run modules/20-defaults.sh."
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
        defaults read "$CHATGPT_APP/Contents/Info" \
            CFBundleIdentifier 2>/dev/null ||
        echo unknown
    )"

    chatgpt_version="$(
        defaults read "$CHATGPT_APP/Contents/Info" \
            CFBundleShortVersionString 2>/dev/null ||
        echo unknown
    )"

    if [[ "$bundle_id" == "com.matthewjordan.chatgpt-left75" ]]; then
        pass "ChatGPT bundle ID" "$bundle_id"
    else
        warn \
            "ChatGPT bundle ID" \
            "$bundle_id" \
            "Review the installed custom ChatGPT application metadata."
    fi

    pass "ChatGPT version" "$chatgpt_version"
else
    fail \
        "ChatGPT metadata" \
        "application missing" \
        "Restore or rebuild ChatGPT-Left75."
fi

if (( ${#warning_guidance[@]} > 0 ||
      ${#failure_guidance[@]} > 0 )); then

    section "Warnings & Actions"

    for item in "${warning_guidance[@]}"; do
        IFS='|' read -r item_label item_detail item_action <<< "$item"

        status_warn
        printf ' %s\n' "$item_label"
        printf '       %s\n' "$item_detail"
        printf '       Review: %s\n' "$item_action"

        {
            printf '[WARN] %s\n' "$item_label"
            printf '       %s\n' "$item_detail"
            printf '       Review: %s\n' "$item_action"
        } >> "$REPORT_FILE"
    done

    for item in "${failure_guidance[@]}"; do
        IFS='|' read -r item_label item_detail item_action <<< "$item"

        status_fail
        printf ' %s\n' "$item_label"
        printf '       %s\n' "$item_detail"
        printf '       Action: %s\n' "$item_action"

        {
            printf '[FAIL] %s\n' "$item_label"
            printf '       %s\n' "$item_detail"
            printf '       Action: %s\n' "$item_action"
        } >> "$REPORT_FILE"
    done
fi

section "Verification Result"

total=$((passes + warnings + failures))

report_status info "Checks performed" "$total"
report_status info "Passed" "$passes"

if (( warnings == 0 )); then
    report_status ok "Warnings" "0"
else
    report_status warn "Warnings" "$warnings"
fi

if (( failures == 0 )); then
    report_status ok "Failures" "0"
    report_status ok "Overall status" "PASS"
else
    report_status fail "Failures" "$failures"
    report_status fail "Overall status" "INCOMPLETE"
fi

larry_info "Verification report: $REPORT_FILE"

if (( failures > 0 )); then
    exit 1
fi

exit 0
