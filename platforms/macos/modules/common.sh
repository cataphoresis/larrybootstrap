#!/usr/bin/env bash

# Shared LarryBBS terminal helpers for the macOS bootstrap.
#
# Interactive terminal output may use ANSI color. Modules that write persistent
# reports should keep those report files plain text.

if [[ -z "${LARRY_COLOR+x}" ]]; then
    if [[ -t 1 ]]; then
        LARRY_COLOR=1
    else
        LARRY_COLOR=0
    fi
fi
export LARRY_COLOR

if [[ "$LARRY_COLOR" == "1" ]]; then
    LARRY_GREEN=$'\033[32m'
    LARRY_YELLOW=$'\033[33m'
    LARRY_RED=$'\033[31m'
    LARRY_CYAN=$'\033[96m'
    LARRY_DARK_CYAN=$'\033[36m'
    LARRY_DARK_GRAY=$'\033[90m'
    LARRY_RESET=$'\033[0m'
else
    LARRY_GREEN=""
    LARRY_YELLOW=""
    LARRY_RED=""
    LARRY_CYAN=""
    LARRY_DARK_CYAN=""
    LARRY_DARK_GRAY=""
    LARRY_RESET=""
fi

larry_section() {
    local title="$1"

    printf '\n%s+--------------------------------------------------------------------------+%s\n' \
        "$LARRY_DARK_CYAN" "$LARRY_RESET"

    printf '%s|  %s%-70.70s%s  |%s\n' \
        "$LARRY_DARK_CYAN" \
        "$LARRY_CYAN" \
        "$title" \
        "$LARRY_DARK_CYAN" \
        "$LARRY_RESET"

    printf '%s+--------------------------------------------------------------------------+%s\n' \
        "$LARRY_DARK_CYAN" "$LARRY_RESET"
}
status_ok() {
    printf '%s[ OK ]%s' "$LARRY_GREEN" "$LARRY_RESET"
}

status_warn() {
    printf '%s[WARN]%s' "$LARRY_YELLOW" "$LARRY_RESET"
}

status_fail() {
    printf '%s[FAIL]%s' "$LARRY_RED" "$LARRY_RESET"
}

status_info() {
    printf '%s[INFO]%s' "$LARRY_CYAN" "$LARRY_RESET"
}

larry_ok() {
    status_ok
    printf ' %s\n' "$*"
}

larry_warn() {
    status_warn
    printf ' %s\n' "$*" >&2
}

larry_fail() {
    status_fail
    printf ' %s\n' "$*" >&2
}

larry_info() {
    status_info
    printf ' %s\n' "$*"
}

larry_stage() {
    printf '\n%s-- %s%s\n' \
        "$LARRY_DARK_GRAY" "$*" "$LARRY_RESET"
}

larry_guidance() {
    printf '  %s%s%s\n' \
        "$LARRY_DARK_GRAY" "$*" "$LARRY_RESET"
}
