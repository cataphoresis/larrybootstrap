#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
BACKUP_DIR="$ROOT_DIR/backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/inventory-$TIMESTAMP.txt"
BACKUP_PATH="$BACKUP_DIR/inventory-$TIMESTAMP"

mkdir -p "$REPORT_DIR" "$BACKUP_PATH"

warning_count=0

log() {
    printf '%-30s %s\n' "$1" "$2" | tee -a "$REPORT_FILE"
}

section() {
    printf '\n%s\n%s\n' "$1" "$(printf '%*s' "${#1}" '' | tr ' ' '=')" \
        | tee -a "$REPORT_FILE"
}

warn() {
    log "$1" "WARNING — $2"
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
    log "System profile" "$BACKUP_PATH/system-profile.txt"
else
    warn "System profile" "could not be collected"
fi

if sw_vers > "$BACKUP_PATH/macos-version.txt" 2>/dev/null; then
    log "macOS version" "$BACKUP_PATH/macos-version.txt"
else
    warn "macOS version" "could not be collected"
fi

if diskutil list > "$BACKUP_PATH/disk-layout.txt" 2>/dev/null; then
    log "Disk layout" "$BACKUP_PATH/disk-layout.txt"
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
    log "Application inventory" "$BACKUP_PATH/applications.txt"
    log "Applications found" "$APP_COUNT"
else
    warn "Application inventory" "could not be completed"
fi

section "Homebrew Snapshot"

if command_exists brew; then
    if brew list --formula 2>/dev/null \
        | sort > "$BACKUP_PATH/brew-formulae.txt"
    then
        log "Formula inventory" "$BACKUP_PATH/brew-formulae.txt"
    else
        warn "Formula inventory" "could not be collected"
    fi

    if brew list --cask 2>/dev/null \
        | sort > "$BACKUP_PATH/brew-casks.txt"
    then
        log "Cask inventory" "$BACKUP_PATH/brew-casks.txt"
    else
        warn "Cask inventory" "could not be collected"
    fi

    if brew bundle dump \
        --file="$BACKUP_PATH/Brewfile" \
        --force \
        >/dev/null 2>&1
    then
        log "Brewfile snapshot" "$BACKUP_PATH/Brewfile"
    else
        warn "Brewfile snapshot" "brew bundle dump failed"
    fi

    if brew config > "$BACKUP_PATH/brew-config.txt" 2>/dev/null; then
        log "Homebrew configuration" "$BACKUP_PATH/brew-config.txt"
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

        log "$tool" "$BACKUP_PATH/$tool.txt"
    else
        log "$tool" "Not installed"
    fi
done

if command_exists cargo; then
    if cargo install --list \
        > "$BACKUP_PATH/cargo-installed.txt" 2>/dev/null
    then
        log "Cargo packages" "$BACKUP_PATH/cargo-installed.txt"
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
    log "Installed application" "$CHATGPT_INSTALLED"

    defaults read "$CHATGPT_INSTALLED/Contents/Info" \
        > "$BACKUP_PATH/chatgpt-left75-info.txt" 2>/dev/null || true

    if [[ -s "$BACKUP_PATH/chatgpt-left75-info.txt" ]]; then
        log "Application metadata" "$BACKUP_PATH/chatgpt-left75-info.txt"
    else
        warn "Application metadata" "could not be read"
    fi
else
    log "Installed application" "Not found"
fi

if [[ -d "$CHATGPT_PROJECT" ]]; then
    log "Source project" "$CHATGPT_PROJECT"

    if command_exists git && git -C "$CHATGPT_PROJECT" status \
        > "$BACKUP_PATH/chatgpt-project-git-status.txt" 2>/dev/null
    then
        log "Project Git status" "$BACKUP_PATH/chatgpt-project-git-status.txt"
    fi
else
    log "Source project" "Not found"
fi

if [[ -d "$CHATGPT_BUILT_APP" ]]; then
    log "Built application" "$CHATGPT_BUILT_APP"
else
    log "Built application" "Not found"
fi

section "Login and Launch Items"

LOGIN_ITEMS_FILE="$BACKUP_PATH/login-items.txt"

if osascript > "$LOGIN_ITEMS_FILE" 2>/dev/null <<'APPLESCRIPT'
tell application "System Events"
    get the name of every login item
end tell
APPLESCRIPT
then
    log "Login-item inventory" "$LOGIN_ITEMS_FILE"
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
        log "User LaunchAgents" "$BACKUP_PATH/user-launchagents.txt"
    else
        warn "User LaunchAgents" "could not be collected"
    fi
else
    : > "$BACKUP_PATH/user-launchagents.txt"
    log "User LaunchAgents" "Directory does not exist"
fi

if [[ -d "/Library/LaunchAgents" ]]; then
    find /Library/LaunchAgents \
        -maxdepth 1 \
        -type f \
        -name '*.plist' \
        2>/dev/null \
        | sort \
        > "$BACKUP_PATH/system-launchagents.txt" || true

    log "System LaunchAgents" "$BACKUP_PATH/system-launchagents.txt"
fi

section "Preference Snapshots"

snapshot_defaults() {
    local domain="$1"
    local output="$2"
    local label="$3"

    if defaults read "$domain" > "$output" 2>/dev/null; then
        log "$label" "$output"
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

snapshot_defaults com.apple.trackpad \
    "$BACKUP_PATH/trackpad-defaults.txt" \
    "Trackpad preferences"

section "Power and Display"

if pmset -g custom > "$BACKUP_PATH/power-settings.txt" 2>/dev/null; then
    log "Power settings" "$BACKUP_PATH/power-settings.txt"
else
    warn "Power settings" "could not be collected"
fi

if system_profiler SPDisplaysDataType \
    > "$BACKUP_PATH/display-profile.txt" 2>/dev/null
then
    log "Display profile" "$BACKUP_PATH/display-profile.txt"
else
    warn "Display profile" "could not be collected"
fi

section "Network Snapshot"

if networksetup -listallhardwareports \
    > "$BACKUP_PATH/network-hardware-ports.txt" 2>/dev/null
then
    log "Network hardware" "$BACKUP_PATH/network-hardware-ports.txt"
else
    warn "Network hardware" "could not be collected"
fi

if scutil --dns > "$BACKUP_PATH/dns-configuration.txt" 2>/dev/null; then
    log "DNS configuration" "$BACKUP_PATH/dns-configuration.txt"
else
    warn "DNS configuration" "could not be collected"
fi

section "Inventory Result"

log "Warnings" "$warning_count"
log "Status" "COMPLETE"

if (( warning_count > 0 )); then
    log "Notice" "Optional items were skipped; bootstrap may continue"
else
    log "Notice" "All inventory operations completed"
fi

printf '\nInventory report: %s\n' "$REPORT_FILE"
printf 'Snapshot directory: %s\n' "$BACKUP_PATH"

exit 0
