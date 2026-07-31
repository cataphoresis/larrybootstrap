#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
BACKUP_DIR="$ROOT_DIR/backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/preflight-$TIMESTAMP.txt"
BACKUP_PATH="$BACKUP_DIR/preflight-$TIMESTAMP"

mkdir -p "$REPORT_DIR" "$BACKUP_PATH"

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

app_exists() {
    [[ -d "/Applications/$1.app" || -d "$HOME/Applications/$1.app" ]]
}

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
    log "Architecture check" "WARNING — expected x86_64, found $ARCH"
fi

section "macOS"

MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_BUILD="$(sw_vers -buildVersion)"
MACOS_NAME="$(sw_vers -productName)"

log "Operating system" "$MACOS_NAME"
log "Version" "$MACOS_VERSION"
log "Build" "$MACOS_BUILD"

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
else
    log "Disk-space check" "FAIL — less than 10 GB free"
fi

section "Developer Tools"

if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools" "INSTALLED"
    log "Developer directory" "$(xcode-select -p)"
else
    log "Xcode Command Line Tools" "NOT INSTALLED"
fi

if command_exists git; then
    log "Git" "$(git --version)"
else
    log "Git" "NOT INSTALLED"
fi

if command_exists brew; then
    log "Homebrew" "$(brew --version | head -n 1)"
    log "Homebrew prefix" "$(brew --prefix)"
else
    log "Homebrew" "NOT INSTALLED"
fi

if command_exists rustc; then
    log "Rust" "$(rustc --version)"
else
    log "Rust" "NOT INSTALLED"
fi

if command_exists cargo; then
    log "Cargo" "$(cargo --version)"
else
    log "Cargo" "NOT INSTALLED"
fi

if command_exists cargo-tauri; then
    log "Tauri CLI" "$(cargo-tauri --version 2>/dev/null || echo installed)"
elif command_exists cargo && cargo tauri --version >/dev/null 2>&1; then
    log "Tauri CLI" "$(cargo tauri --version)"
else
    log "Tauri CLI" "NOT INSTALLED"
fi

if command_exists node; then
    log "Node.js" "$(node --version)"
else
    log "Node.js" "NOT INSTALLED"
fi

if command_exists npm; then
    log "npm" "$(npm --version)"
else
    log "npm" "NOT INSTALLED"
fi

section "Security and Boot"

if csrutil status >/dev/null 2>&1; then
    log "System Integrity Protection" "$(csrutil status | sed 's/\.$//')"
else
    log "System Integrity Protection" "Unable to query"
fi

if fdesetup status >/dev/null 2>&1; then
    log "FileVault" "$(fdesetup status | sed 's/\.$//')"
else
    log "FileVault" "Unable to query"
fi

log "Gatekeeper" "$(spctl --status 2>&1 || true)"

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

    BUNDLE_ID="$(
        defaults read "$CHATGPT_INSTALLED/Contents/Info" CFBundleIdentifier \
            2>/dev/null || echo unknown
    )"

    APP_VERSION="$(
        defaults read "$CHATGPT_INSTALLED/Contents/Info" CFBundleShortVersionString \
            2>/dev/null || echo unknown
    )"

    log "Bundle identifier" "$BUNDLE_ID"
    log "Application version" "$APP_VERSION"
else
    log "Installed application" "NOT FOUND"
fi

if [[ -d "$CHATGPT_PROJECT" ]]; then
    log "Source project" "$CHATGPT_PROJECT"
else
    log "Source project" "NOT FOUND"
fi

if [[ -d "$CHATGPT_BUILT_APP" ]]; then
    log "Built application" "$CHATGPT_BUILT_APP"
else
    log "Built application" "NOT FOUND"
fi

section "Installed Application Snapshot"

APP_DIRECTORIES=("/Applications")

if [[ -d "$HOME/Applications" ]]; then
    APP_DIRECTORIES+=("$HOME/Applications")
fi

find "${APP_DIRECTORIES[@]}" \
    -maxdepth 1 \
    -type d \
    -name '*.app' \
    2>/dev/null \
    | sort \
    > "$BACKUP_PATH/applications.txt"

log "Application inventory" "$BACKUP_PATH/applications.txt"

section "Homebrew Snapshot"

if command_exists brew; then
    brew list --formula 2>/dev/null | sort > "$BACKUP_PATH/brew-formulae.txt"
    brew list --cask 2>/dev/null | sort > "$BACKUP_PATH/brew-casks.txt"
    brew bundle dump \
        --file="$BACKUP_PATH/Brewfile" \
        --force \
        >/dev/null 2>&1 || true

    log "Formula inventory" "$BACKUP_PATH/brew-formulae.txt"
    log "Cask inventory" "$BACKUP_PATH/brew-casks.txt"
    log "Brewfile snapshot" "$BACKUP_PATH/Brewfile"
else
    log "Homebrew snapshot" "Skipped — Homebrew not installed"
fi

section "Login and Launch Items"

osascript -e '
tell application "System Events"
    get the name of every login item
end tell
' > "$BACKUP_PATH/login-items.txt" 2>/dev/null || true

find "$HOME/Library/LaunchAgents" \
    -maxdepth 1 \
    -type f \
    -name '*.plist' \
    2>/dev/null \
    | sort \
    > "$BACKUP_PATH/user-launchagents.txt"

log "Login-item inventory" "$BACKUP_PATH/login-items.txt"
log "User LaunchAgents" "$BACKUP_PATH/user-launchagents.txt"

section "System Preference Snapshot"

defaults read com.apple.finder \
    > "$BACKUP_PATH/finder-defaults.txt" 2>/dev/null || true

defaults read com.apple.dock \
    > "$BACKUP_PATH/dock-defaults.txt" 2>/dev/null || true

defaults read NSGlobalDomain \
    > "$BACKUP_PATH/global-defaults.txt" 2>/dev/null || true

pmset -g custom \
    > "$BACKUP_PATH/power-settings.txt" 2>/dev/null || true

system_profiler SPHardwareDataType SPSoftwareDataType \
    > "$BACKUP_PATH/system-profile.txt" 2>/dev/null || true

log "Finder preferences" "$BACKUP_PATH/finder-defaults.txt"
log "Dock preferences" "$BACKUP_PATH/dock-defaults.txt"
log "Global preferences" "$BACKUP_PATH/global-defaults.txt"
log "Power settings" "$BACKUP_PATH/power-settings.txt"
log "System profile" "$BACKUP_PATH/system-profile.txt"

section "Preflight Result"

FAILURES=0

if (( ROOT_FREE_GB < 10 )); then
    log "Blocking issue" "Insufficient disk space"
    FAILURES=$((FAILURES + 1))
fi

if [[ "$(id -u)" -eq 0 ]]; then
    log "Blocking issue" "Do not run bootstrap directly as root"
    FAILURES=$((FAILURES + 1))
fi

if (( FAILURES == 0 )); then
    log "Status" "PASS"
    log "Next stage" "Homebrew and application installation"
else
    log "Status" "FAIL — $FAILURES blocking issue(s)"
fi

printf '\nPreflight report: %s\n' "$REPORT_FILE"
printf 'Snapshot directory: %s\n' "$BACKUP_PATH"
