#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=modules/common.sh
source "$ROOT_DIR/modules/common.sh"

REPORT_DIR="$ROOT_DIR/reports"
BACKUP_DIR="$ROOT_DIR/backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/defaults-$TIMESTAMP.txt"
MACBOOK_DRY_RUN="${MACBOOK_DRY_RUN:-0}"
BACKUP_PATH="$BACKUP_DIR/defaults-$TIMESTAMP"

if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    REPORT_FILE="/dev/null"
else
    mkdir -p \
        "$REPORT_DIR" \
        "$BACKUP_PATH" \
        "$HOME/Pictures/Screenshots"
fi

failures=0
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

verify_default() {
    local domain="$1"
    local key="$2"
    local expected="$3"
    local label="$4"
    local display="$5"
    local actual

    actual="$(
        defaults read "$domain" "$key" 2>/dev/null ||
            echo unavailable
    )"

    if [[ "$actual" == "$expected" ]]; then
        report_status ok "$label" "$display"
    else
        report_status fail \
            "$label" \
            "expected $expected; found $actual"
        failures=$((failures + 1))
    fi
}

section "macOS Defaults Configuration"

report_status info "Current user" "$(id -un)"
report_status info "Backup" "$(basename "$BACKUP_PATH")"

section "Backing Up Current Preferences"

if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    report_status info "Preference backup" "skipped in dry-run"
else
    for domain in \
        NSGlobalDomain \
        com.apple.finder \
        com.apple.dock \
        com.apple.screencapture \
        com.apple.universalaccess \
        com.apple.AppleMultitouchTrackpad
    do
        safe_name="$(printf '%s' "$domain" | tr '.' '_')"

        defaults read "$domain" \
            > "$BACKUP_PATH/${safe_name}.txt" 2>/dev/null || true
    done

    report_status ok "Preference backup" "captured"
fi

section "Finder"
if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    report_status info "Finder changes" "would apply"
else

    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    defaults write com.apple.finder ShowPathbar -bool true
    defaults write com.apple.finder ShowStatusBar -bool true
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
    defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
    defaults write com.apple.finder _FXSortFoldersFirst -bool true
    defaults write com.apple.finder QLEnableTextSelection -bool true
    defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

fi

verify_default \
    NSGlobalDomain AppleShowAllExtensions 1 \
    "Filename extensions" "enabled"

verify_default \
    com.apple.finder ShowPathbar 1 \
    "Path bar" "enabled"

verify_default \
    com.apple.finder ShowStatusBar 1 \
    "Status bar" "enabled"

verify_default \
    com.apple.finder FXPreferredViewStyle Nlsv \
    "Default view" "List"

verify_default \
    com.apple.finder FXDefaultSearchScope SCcf \
    "Search scope" "Current folder"

verify_default \
    com.apple.finder _FXSortFoldersFirst 1 \
    "Folders first" "enabled"

verify_default \
    com.apple.finder FXEnableExtensionChangeWarning 0 \
    "Extension warning" "disabled"

section "Dock"
if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    report_status info "Dock changes" "would apply"
else

    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.dock autohide-delay -float 0
    defaults write com.apple.dock autohide-time-modifier -float 0.18
    defaults write com.apple.dock tilesize -int 42
    defaults write com.apple.dock show-recents -bool false
    defaults write com.apple.dock launchanim -bool false
    defaults write com.apple.dock mineffect -string "scale"

fi

verify_default \
    com.apple.dock autohide 1 \
    "Auto-hide" "enabled"

verify_default \
    com.apple.dock autohide-delay 0 \
    "Auto-hide delay" "0"

verify_default \
    com.apple.dock tilesize 42 \
    "Dock size" "42"

verify_default \
    com.apple.dock show-recents 0 \
    "Recent applications" "disabled"

verify_default \
    com.apple.dock launchanim 0 \
    "Launch animation" "disabled"

verify_default \
    com.apple.dock mineffect scale \
    "Minimize effect" "scale"

section "Keyboard"
if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    report_status info "Keyboard changes" "would apply"
else

    defaults write NSGlobalDomain KeyRepeat -int 2
    defaults write NSGlobalDomain InitialKeyRepeat -int 15
    defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
    defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

fi

verify_default \
    NSGlobalDomain KeyRepeat 2 \
    "Key repeat" "2"

verify_default \
    NSGlobalDomain InitialKeyRepeat 15 \
    "Initial repeat delay" "15"

verify_default \
    NSGlobalDomain ApplePressAndHoldEnabled 0 \
    "Press-and-hold" "disabled"

verify_default \
    NSGlobalDomain AppleKeyboardUIMode 3 \
    "Keyboard navigation" "enabled"

section "Trackpad"
if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    report_status info "Trackpad changes" "would apply"
else

    defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
    defaults write \
        com.apple.driver.AppleBluetoothMultitouch.trackpad \
        Clicking -bool true

    defaults write \
        NSGlobalDomain \
        com.apple.mouse.tapBehavior -int 1

    defaults -currentHost write \
        NSGlobalDomain \
        com.apple.mouse.tapBehavior -int 1

    defaults write \
        com.apple.AppleMultitouchTrackpad \
        TrackpadRightClick -bool true

    defaults write \
        com.apple.driver.AppleBluetoothMultitouch.trackpad \
        TrackpadRightClick -bool true

fi

verify_default \
    com.apple.AppleMultitouchTrackpad Clicking 1 \
    "Tap to click" "enabled"

verify_default \
    com.apple.AppleMultitouchTrackpad TrackpadRightClick 1 \
    "Two-finger right-click" "enabled"

section "Screenshots"
if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    report_status info "Screenshots changes" "would apply"
else

    defaults write \
        com.apple.screencapture \
        location -string "$HOME/Pictures/Screenshots"

    defaults write \
        com.apple.screencapture \
        type -string "png"

    defaults write \
        com.apple.screencapture \
        disable-shadow -bool true

fi

verify_default \
    com.apple.screencapture location \
    "$HOME/Pictures/Screenshots" \
    "Screenshot folder" "~/Pictures/Screenshots"

verify_default \
    com.apple.screencapture type png \
    "Screenshot format" "PNG"

verify_default \
    com.apple.screencapture disable-shadow 1 \
    "Window shadows" "disabled"

section "Responsiveness"
if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    report_status info "Responsiveness changes" "would apply"
else

    defaults write \
        com.apple.universalaccess \
        reduceMotion -bool true

    defaults write \
        com.apple.universalaccess \
        reduceTransparency -bool true

    defaults write \
        NSGlobalDomain \
        NSAutomaticWindowAnimationsEnabled -bool false

    defaults write \
        NSGlobalDomain \
        QLPanelAnimationDuration -float 0

    defaults write \
        NSGlobalDomain \
        NSNavPanelExpandedStateForSaveMode -bool true

    defaults write \
        NSGlobalDomain \
        NSNavPanelExpandedStateForSaveMode2 -bool true

    defaults write \
        NSGlobalDomain \
        PMPrintingExpandedStateForPrint -bool true

    defaults write \
        NSGlobalDomain \
        PMPrintingExpandedStateForPrint2 -bool true

fi

verify_default \
    com.apple.universalaccess reduceMotion 1 \
    "Reduce motion" "enabled"

verify_default \
    com.apple.universalaccess reduceTransparency 1 \
    "Reduce transparency" "enabled"

verify_default \
    NSGlobalDomain NSAutomaticWindowAnimationsEnabled 0 \
    "Window animations" "disabled"

section "Applying Changes"

if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    report_status info "Finder restart" "skipped in dry-run"
    report_status info "Dock restart" "skipped in dry-run"
    report_status info "System UI restart" "skipped in dry-run"
else
    killall Finder 2>/dev/null || true
    killall Dock 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true

    report_status ok "Finder restart" "complete"
    report_status ok "Dock restart" "complete"
    report_status ok "System UI restart" "complete"
fi

section "Defaults Result"

if (( failures == 0 )); then
    report_status ok "Failures" "0"
    report_status ok "Status" "COMPLETE"
else
    report_status fail "Failures" "$failures"
    report_status fail "Status" "INCOMPLETE"
fi

if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    report_status info "Backup" "not written in dry-run"
    larry_info "Defaults report: not written in dry-run"
    larry_info "Backup directory: not created in dry-run"
else
    report_status info "Backup" "$(basename "$BACKUP_PATH")"
    larry_info "Defaults report: $REPORT_FILE"
    larry_info "Backup directory: $BACKUP_PATH"
fi

larry_info "Some keyboard/accessibility changes may require logout/login."

exit 0
