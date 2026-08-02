#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
BACKUP_DIR="$ROOT_DIR/backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/defaults-$TIMESTAMP.txt"
BACKUP_PATH="$BACKUP_DIR/defaults-$TIMESTAMP"

mkdir -p "$REPORT_DIR" "$BACKUP_PATH" "$HOME/Pictures/Screenshots"

log() {
    printf '%-32s %s\n' "$1" "$2" | tee -a "$REPORT_FILE"
}

section() {
    printf '\n%s\n%s\n' "$1" "$(printf '%*s' "${#1}" '' | tr ' ' '=')" \
        | tee -a "$REPORT_FILE"
}

section "macOS Defaults Configuration"

log "Run date" "$(date)"
log "Current user" "$(id -un)"
log "Backup directory" "$BACKUP_PATH"

section "Backing Up Current Preferences"

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

log "Preference backup" "COMPLETE"

section "Finder"

# Show all filename extensions.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show the Finder path bar and status bar.
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

# Use list view by default.
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Search the current folder instead of the entire Mac by default.
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Keep folders above files when sorting by name.
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Allow text selection in Quick Look.
defaults write com.apple.finder QLEnableTextSelection -bool true

# Avoid warning when changing filename extensions.
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

log "Finder configuration" "APPLIED"

section "Dock"

# Automatically hide the Dock.
defaults write com.apple.dock autohide -bool true

# Show the Dock quickly.
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.18

# Use a compact but readable Dock size.
defaults write com.apple.dock tilesize -int 42

# Do not add recent applications to the Dock.
defaults write com.apple.dock show-recents -bool false

# Remove unnecessary launch animation.
defaults write com.apple.dock launchanim -bool false

# Minimize windows using the simpler scale effect.
defaults write com.apple.dock mineffect -string "scale"

log "Dock configuration" "APPLIED"

section "Keyboard"

# Faster key repeat with a short initial delay.
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable press-and-hold accent popup so keys repeat normally.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Enable full keyboard navigation through interface controls.
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

log "Keyboard configuration" "APPLIED"

section "Trackpad"

# Enable tap-to-click for the built-in trackpad.
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Keep right-click via two-finger click enabled.
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true

log "Trackpad configuration" "APPLIED"

section "Screenshots"

defaults write com.apple.screencapture location \
    -string "$HOME/Pictures/Screenshots"

defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

log "Screenshot folder" "$HOME/Pictures/Screenshots"
log "Screenshot configuration" "APPLIED"

section "Responsiveness"

# Reduce visual effects on this low-power Core m3.
defaults write com.apple.universalaccess reduceMotion -bool true
defaults write com.apple.universalaccess reduceTransparency -bool true

# Disable standard window-opening animation.
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

# Speed up Quick Look panels.
defaults write NSGlobalDomain QLPanelAnimationDuration -float 0

# Expand save and print dialogs by default.
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

log "Reduced motion" "ENABLED"
log "Reduced transparency" "ENABLED"
log "Interface responsiveness" "TUNED"

section "Applying Changes"

killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

log "Finder restart" "COMPLETE"
log "Dock restart" "COMPLETE"
log "System UI restart" "COMPLETE"

section "Defaults Result"

log "Status" "COMPLETE"
log "Report" "$REPORT_FILE"
log "Backup" "$BACKUP_PATH"

printf '\nSome keyboard and accessibility changes may require logout/login.\n'
