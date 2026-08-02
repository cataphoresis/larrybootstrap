#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/filezilla-$TIMESTAMP.txt"

APP_PATH="/Applications/FileZilla.app"
DOWNLOADS_DIR="$HOME/Downloads"

mkdir -p "$REPORT_DIR"

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

if [[ -d "$APP_PATH" ]]; then
    log "FileZilla" "PRESENT — $APP_PATH"
    log "Status" "COMPLETE"
    exit 0
fi

ARCHIVE="$(
    find "$DOWNLOADS_DIR" \
        -maxdepth 1 \
        -type f \
        -iname 'FileZilla_*_macos-x86.app.tar.bz2' \
        -print \
        | sort \
        | tail -n 1
)"

if [[ -z "$ARCHIVE" ]]; then
    log "Status" "SKIPPED — compatible Intel archive not found in ~/Downloads"
    log "Expected pattern" "FileZilla_*_macos-x86.app.tar.bz2"
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

log "Archive" "$ARCHIVE"

if ! tar -xjf "$ARCHIVE" -C "$TMP_DIR"; then
    log "Status" "FAILED — archive extraction unsuccessful"
    exit 0
fi

EXTRACTED_APP="$(
    find "$TMP_DIR" \
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

if [[ -d "$APP_PATH" ]]; then
    log "Verification" "PASS"
    log "Status" "COMPLETE"
else
    log "Verification" "FAIL"
    log "Status" "FAILED"
fi
