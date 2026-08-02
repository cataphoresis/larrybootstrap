#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
    Darwin)
        PLATFORM_BOOTSTRAP="$ROOT_DIR/platforms/macos/bootstrap.sh"
        ;;
    Linux)
        PLATFORM_BOOTSTRAP="$ROOT_DIR/platforms/linux/bootstrap.sh"
        ;;
    *)
        printf 'ERROR: Unsupported operating system: %s\n' "$(uname -s)" >&2
        exit 1
        ;;
esac

if [[ ! -x "$PLATFORM_BOOTSTRAP" ]]; then
    printf 'ERROR: Platform bootstrap is missing or not executable: %s\n' \
        "$PLATFORM_BOOTSTRAP" >&2
    exit 1
fi

exec "$PLATFORM_BOOTSTRAP" "$@"
