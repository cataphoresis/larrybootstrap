#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
DOWNLOAD_DIR="$HOME/Downloads/MacBook-Bootstrap"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/filezilla-$TIMESTAMP.txt"

APP_PATH="/Applications/FileZilla.app"
DOWNLOAD_URL="https://download.filezilla-project.org/client/FileZilla_latest_macosx-x86.app.tar.bz2"
ARCHIVE="$DOWNLOAD_DIR/FileZilla-macos-intel.tar.bz2"
EXTRACT_DIR="$DOWNLOAD_DIR/filezilla-extracted"

mkdir -p "$REPORT_DIR" "$DOWNLOAD_DIR"

log() {
    printf '%-28s %s\n' "$1" "$2" | tee -a "$REPORT_FILE"
}

section() {
    printf '\n%s\n%s\n' "$1" "$(printf '%*s' "${#1}" '' | tr ' ' '=')" \
        | tee -a "$REPORT_FILE"
}

section "FileZilla Installation"

log "Run date" "$(date)"
log "Architecture" "$(uname -m)"

if [[ "$(uname -m)" != "x86_64" ]]; then
    log "Status" "SKIPPED — this installer is for Intel Macs"
    exit 0
fi

if [[ -d "$APP_PATH" ]]; then
    log "FileZilla" "PRESENT — $APP_PATH"
    log "Status" "COMPLETE"
    exit 0
fi

rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"

log "Download" "Starting official Intel build"

if ! curl \
    --fail \
    --location \
    --retry 3 \
    --connect-timeout 20 \
    "$DOWNLOAD_URL" \
    --output "$ARCHIVE"
then
    log "Status" "FAILED — download unsuccessful"
    exit 0
fi

if ! tar -xjf "$ARCHIVE" -C "$EXTRACT_DIR"; then
    log "Status" "FAILED — archive extraction unsuccessful"
    exit 0
fi

EXTRACTED_APP="$(
    find "$EXTRACT_DIR" \
        -maxdepth 2 \
        -type d \
        -name 'FileZilla.app' \
        -print \
        -quit
)"

if [[ -z "$EXTRACTED_APP" ]]; then
    log "Status" "FAILED — FileZilla.app not found in archive"
    exit 0
fi

if sudo ditto "$EXTRACTED_APP" "$APP_PATH"; then
    log "FileZilla" "INSTALLED — $APP_PATH"
else
    log "Status" "FAILED — could not copy application"
    exit 0
fi

xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true

if [[ -d "$APP_PATH" ]]; then
    log "Verification" "PASS"
    log "Status" "COMPLETE"
else
    log "Verification" "FAIL"
    log "Status" "FAILED"
fi

printf '\nFileZilla report: %s\n' "$REPORT_FILE"
