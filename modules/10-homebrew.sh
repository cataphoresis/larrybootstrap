#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/homebrew-$TIMESTAMP.txt"

PROFILE="${MACBOOK_PROFILE:-standard}"
PROFILE_FILE="$ROOT_DIR/profiles/$PROFILE.conf"

mkdir -p "$REPORT_DIR"

installed_count=0
present_count=0
skipped_count=0
failed_count=0

log() {
    printf '%-28s %s\n' "$1" "$2" | tee -a "$REPORT_FILE"
}

section() {
    printf '\n%s\n%s\n' "$1" "$(printf '%*s' "${#1}" '' | tr ' ' '=')" \
        | tee -a "$REPORT_FILE"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

section "Homebrew Installation"

log "Run date" "$(date)"
log "Requested profile" "$PROFILE"
log "Profile file" "$PROFILE_FILE"

if [[ ! -f "$PROFILE_FILE" ]]; then
    log "Status" "FAIL — unknown profile: $PROFILE"
    log "Available profiles" "$(find "$ROOT_DIR/profiles" -name '*.conf' -exec basename {} .conf \; | sort | tr '\n' ' ')"
    exit 1
fi

if ! command_exists brew; then
    log "Homebrew" "Not installed; beginning installation"

    if ! command_exists curl; then
        log "Status" "FAIL — curl is unavailable"
        exit 1
    fi

    if ! /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    then
        log "Status" "FAIL — Homebrew installation failed"
        exit 1
    fi
fi

if [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! command_exists brew; then
    log "Status" "FAIL — Homebrew is still unavailable"
    exit 1
fi

log "Homebrew" "$(brew --version | head -n 1)"
log "Prefix" "$(brew --prefix)"

# shellcheck disable=SC1090
source "$PROFILE_FILE"

section "Homebrew Maintenance"

if brew update; then
    log "Repository update" "COMPLETE"
else
    log "Repository update" "WARNING — update failed; continuing with current metadata"
fi

section "Formulae"

for formula in "${FORMULAE[@]}"; do
    if brew list --formula "$formula" >/dev/null 2>&1; then
        log "$formula" "PRESENT"
        present_count=$((present_count + 1))
        continue
    fi

    if ! brew info --formula "$formula" >/dev/null 2>&1; then
        log "$formula" "SKIPPED — formula unavailable"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    log "$formula" "Installing"

    if brew install "$formula"; then
        log "$formula" "INSTALLED"
        installed_count=$((installed_count + 1))
    else
        log "$formula" "FAILED — bootstrap will continue"
        failed_count=$((failed_count + 1))
    fi
done

section "Applications"

for cask in "${CASKS[@]}"; do
    if brew list --cask "$cask" >/dev/null 2>&1; then
        log "$cask" "PRESENT"
        present_count=$((present_count + 1))
        continue
    fi

    if ! brew info --cask "$cask" >/dev/null 2>&1; then
        log "$cask" "SKIPPED — cask unavailable or unsupported"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    log "$cask" "Installing"

    if brew install --cask "$cask"; then
        log "$cask" "INSTALLED"
        installed_count=$((installed_count + 1))
    else
        log "$cask" "FAILED — unavailable, incompatible, or installer declined"
        failed_count=$((failed_count + 1))
    fi
done

section "Cleanup"

if brew cleanup; then
    log "Homebrew cleanup" "COMPLETE"
else
    log "Homebrew cleanup" "WARNING — cleanup returned an error"
fi

section "Homebrew Result"

log "Already present" "$present_count"
log "Newly installed" "$installed_count"
log "Skipped" "$skipped_count"
log "Failed" "$failed_count"

if (( failed_count == 0 )); then
    log "Status" "COMPLETE"
else
    log "Status" "COMPLETE WITH WARNINGS"
fi

printf '\nHomebrew report: %s\n' "$REPORT_FILE"

# Package incompatibility is nonblocking. A later verification module will
# distinguish essential packages from optional packages.
exit 0
