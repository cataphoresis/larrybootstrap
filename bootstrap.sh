#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$ROOT_DIR/modules"

log() {
    printf '\n==> %s\n' "$1"
}

fail() {
    printf '\nERROR: %s\n' "$1" >&2
    exit 1
}

[[ "$(uname -s)" == "Darwin" ]] || fail "This bootstrap must be run on macOS."

log "Starting MacBook bootstrap"

for module in "$MODULE_DIR"/*.sh; do
    [[ -e "$module" ]] || continue
    log "Running $(basename "$module")"
    bash "$module"
done

log "Bootstrap completed"
