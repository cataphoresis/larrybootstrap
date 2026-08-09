#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=modules/common.sh
source "$ROOT_DIR/modules/common.sh"

REPORT_DIR="$ROOT_DIR/reports"
BACKUP_DIR="$ROOT_DIR/backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/inventory-$TIMESTAMP.txt"
BACKUP_PATH="$BACKUP_DIR/inventory-$TIMESTAMP"
MACBOOK_DRY_RUN="${MACBOOK_DRY_RUN:-0}"

if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    larry_section "MacBook Bootstrap Inventory"

    status_info
    printf ' %-24s %s\n' "Mode" "dry-run"

    status_info
    printf ' %-24s %s\n' "Inventory snapshot" "would capture"

    status_info
    printf ' %-24s %s\n' "Persistent files" "none"

    larry_info "Inventory collection skipped to preserve zero-write dry-run."
    exit 0
fi

mkdir -p "$REPORT_DIR" "$BACKUP_PATH"

warning_count=0
warning_guidance=()

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

warn() {
    local label="$1"
    local message="$2"

    report_status warn "$label" "$message"

    warning_guidance+=(
        "$label|$message|Review the inventory report if this information is needed."
    )

    warning_count=$((warning_count + 1))
}
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

section "MacBook Bootstrap Inventory"

log "Run date" "$(date)"
log "Snapshot directory" "$BACKUP_PATH"

section "System Summary"

if system_profiler SPHardwareDataType SPSoftwareDataType \
    > "$BACKUP_PATH/system-profile.txt" 2>/dev/null
then
    report_status ok "System profile" "captured"
else
    warn "System profile" "could not be collected"
fi

if sw_vers > "$BACKUP_PATH/macos-version.txt" 2>/dev/null; then
    report_status ok "macOS version" "captured"
else
    warn "macOS version" "could not be collected"
fi

if diskutil list > "$BACKUP_PATH/disk-layout.txt" 2>/dev/null; then
    report_status ok "Disk layout" "captured"
else
    warn "Disk layout" "could not be collected"
fi

section "Installed Applications"

APP_DIRECTORIES=("/Applications")

if [[ -d "$HOME/Applications" ]]; then
    APP_DIRECTORIES+=("$HOME/Applications")
fi

if find "${APP_DIRECTORIES[@]}" \
    -maxdepth 1 \
    -type d \
    -name '*.app' \
    2>/dev/null \
    | sort \
    > "$BACKUP_PATH/applications.txt"
then
    APP_COUNT="$(wc -l < "$BACKUP_PATH/applications.txt" | tr -d ' ')"
    report_status ok "Application inventory" "captured"
    report_status info "Applications found" "$APP_COUNT"
else
    warn "Application inventory" "could not be completed"
fi

section "Homebrew Snapshot"

if command_exists brew; then
    if brew list --formula 2>/dev/null \
        | sort > "$BACKUP_PATH/brew-formulae.txt"
    then
        report_status ok "Formula inventory" "captured"
    else
        warn "Formula inventory" "could not be collected"
    fi

    if brew list --cask 2>/dev/null \
        | sort > "$BACKUP_PATH/brew-casks.txt"
    then
        report_status ok "Cask inventory" "captured"
    else
        warn "Cask inventory" "could not be collected"
    fi

    if brew bundle dump \
        --file="$BACKUP_PATH/Brewfile" \
        --force \
        >/dev/null 2>&1
    then
        report_status ok "Brewfile snapshot" "captured"
    else
        warn "Brewfile snapshot" "brew bundle dump failed"
    fi

    if brew config > "$BACKUP_PATH/brew-config.txt" 2>/dev/null; then
        report_status ok "Homebrew configuration" "captured"
    else
        warn "Homebrew configuration" "could not be collected"
    fi
else
    warn "Homebrew snapshot" "Homebrew is not installed"
fi

section "Developer Environment"

for tool in git rustc cargo node npm python3; do
    if command_exists "$tool"; then
        {
            printf 'Path: '
            command -v "$tool"
            printf 'Version: '
            "$tool" --version 2>&1 | head -n 1
        } > "$BACKUP_PATH/$tool.txt"

        tool_version="$(
            "$tool" --version 2>&1 |
                head -n 1
        )"
        report_status ok "$tool" "$tool_version"
    else
        report_status info "$tool" "not installed"
    fi
done

if command_exists cargo; then
    if cargo install --list \
        > "$BACKUP_PATH/cargo-installed.txt" 2>/dev/null
    then
        report_status ok "Cargo packages" "captured"
    else
        warn "Cargo packages" "could not be collected"
    fi
fi

section "Custom ChatGPT Application"

CHATGPT_INSTALLED=""

for candidate in \
    "/Applications/chatgpt-left75.app" \
    "/Applications/ChatGPT-Left75.app" \
    "$HOME/Applications/chatgpt-left75.app" \
    "$HOME/Applications/ChatGPT-Left75.app"
do
    if [[ -d "$candidate" ]]; then
        CHATGPT_INSTALLED="$candidate"
        break
    fi
done

CHATGPT_PROJECT="$HOME/chatgpt-left75"
CHATGPT_BUILT_APP="$CHATGPT_PROJECT/src-tauri/target/release/bundle/macos/chatgpt-left75.app"

if [[ -n "$CHATGPT_INSTALLED" ]]; then
    report_status ok "Installed application" "chatgpt-left75.app"

    defaults read "$CHATGPT_INSTALLED/Contents/Info" \
        > "$BACKUP_PATH/chatgpt-left75-info.txt" 2>/dev/null || true

    if [[ -s "$BACKUP_PATH/chatgpt-left75-info.txt" ]]; then
        report_status ok "Application metadata" "captured"
    else
        warn "Application metadata" "could not be read"
    fi
else
    report_status info "Installed application" "not found"
fi

if [[ -d "$CHATGPT_PROJECT" ]]; then
    report_status ok "Source project" "chatgpt-left75"

    if command_exists git && git -C "$CHATGPT_PROJECT" status \
        > "$BACKUP_PATH/chatgpt-project-git-status.txt" 2>/dev/null
    then
        report_status ok "Project Git status" "captured"
    fi
else
    report_status info "Source project" "not found"
fi

if [[ -d "$CHATGPT_BUILT_APP" ]]; then
    report_status ok "Built application" "release build present"
else
    report_status info "Built application" "not found"
fi

section "Login and Launch Items"

LOGIN_ITEMS_FILE="$BACKUP_PATH/login-items.txt"

if osascript > "$LOGIN_ITEMS_FILE" 2>/dev/null <<'APPLESCRIPT'
tell application "System Events"
    get the name of every login item
end tell
APPLESCRIPT
then
    report_status ok "Login-item inventory" "captured"
else
    : > "$LOGIN_ITEMS_FILE"
    warn "Login-item inventory" "Automation permission unavailable or System Events declined"
fi

if [[ -d "$HOME/Library/LaunchAgents" ]]; then
    if find "$HOME/Library/LaunchAgents" \
        -maxdepth 1 \
        -type f \
        -name '*.plist' \
        2>/dev/null \
        | sort \
        > "$BACKUP_PATH/user-launchagents.txt"
    then
        report_status ok "User LaunchAgents" "captured"
    else
        warn "User LaunchAgents" "could not be collected"
    fi
else
    : > "$BACKUP_PATH/user-launchagents.txt"
    report_status info "User LaunchAgents" "directory does not exist"
fi

if [[ -d "/Library/LaunchAgents" ]]; then
    find /Library/LaunchAgents \
        -maxdepth 1 \
        -type f \
        -name '*.plist' \
        2>/dev/null \
        | sort \
        > "$BACKUP_PATH/system-launchagents.txt" || true

    report_status ok "System LaunchAgents" "captured"
fi

section "Preference Snapshots"

snapshot_defaults() {
    local domain="$1"
    local output="$2"
    local label="$3"

    if defaults read "$domain" > "$output" 2>/dev/null; then
        report_status ok "$label" "captured"
    else
        : > "$output"
        warn "$label" "domain could not be read"
    fi
}

snapshot_defaults com.apple.finder \
    "$BACKUP_PATH/finder-defaults.txt" \
    "Finder preferences"

snapshot_defaults com.apple.dock \
    "$BACKUP_PATH/dock-defaults.txt" \
    "Dock preferences"

snapshot_defaults NSGlobalDomain \
    "$BACKUP_PATH/global-defaults.txt" \
    "Global preferences"

snapshot_defaults com.apple.screencapture \
    "$BACKUP_PATH/screencapture-defaults.txt" \
    "Screenshot preferences"

snapshot_defaults com.apple.AppleMultitouchTrackpad \
    "$BACKUP_PATH/trackpad-defaults.txt" \
    "Trackpad preferences"

section "Power and Display"

if pmset -g custom > "$BACKUP_PATH/power-settings.txt" 2>/dev/null; then
    report_status ok "Power settings" "captured"
else
    warn "Power settings" "could not be collected"
fi

if system_profiler SPDisplaysDataType \
    > "$BACKUP_PATH/display-profile.txt" 2>/dev/null
then
    report_status ok "Display profile" "captured"
else
    warn "Display profile" "could not be collected"
fi

section "Network Snapshot"

if networksetup -listallhardwareports \
    > "$BACKUP_PATH/network-hardware-ports.txt" 2>/dev/null
then
    report_status ok "Network hardware" "captured"
else
    warn "Network hardware" "could not be collected"
fi

if scutil --dns > "$BACKUP_PATH/dns-configuration.txt" 2>/dev/null; then
    report_status ok "DNS configuration" "captured"
else
    warn "DNS configuration" "could not be collected"
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

section "Inventory Result"

if (( warning_count == 0 )); then
    report_status ok "Warnings" "0"
    report_status ok "Status" "COMPLETE"
else
    report_status warn "Warnings" "$warning_count"
    report_status ok "Status" "COMPLETE"
fi

report_status info "Snapshot" "$(basename "$BACKUP_PATH")"
larry_info "Snapshot directory: $BACKUP_PATH"
larry_info "Inventory report: $REPORT_FILE"

exit 0
