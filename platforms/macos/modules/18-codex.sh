#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=modules/common.sh
source "$ROOT_DIR/modules/common.sh"

REPORT_DIR="$ROOT_DIR/reports"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/codex-$TIMESTAMP.txt"
MACBOOK_DRY_RUN="${MACBOOK_DRY_RUN:-0}"

CODEX_INSTALLER_URL="https://chatgpt.com/codex/install.sh"
CODEX_EXTENSION="openai.chatgpt"

if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    REPORT_FILE="/dev/null"
else
    mkdir -p "$REPORT_DIR"
fi

failures=0

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

resolve_code_command() {
    local candidate
    local app_bin="Contents/Resources/app/bin/code"

    if command -v code >/dev/null 2>&1; then
        command -v code
        return 0
    fi

    for candidate in \
        "/Applications/Visual Studio Code.app/$app_bin" \
        "$HOME/Applications/Visual Studio Code.app/$app_bin"
    do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

resolve_codex_command() {
    local candidate

    if command -v codex >/dev/null 2>&1; then
        command -v codex
        return 0
    fi

    for candidate in \
        "$HOME/.local/bin/codex" \
        "/opt/homebrew/bin/codex" \
        "/usr/local/bin/codex"
    do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

extension_installed() {
    local code_command="$1"

    "$code_command" --list-extensions 2>/dev/null |
        awk -v extension="$CODEX_EXTENSION" \
            'tolower($0) == extension { found=1 } END { exit !found }'
}

install_codex_cli() {
    local installer

    if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
        if codex_command="$(resolve_codex_command)"; then
            report_status ok "Codex CLI" \
                "$("$codex_command" --version 2>/dev/null | head -n 1)"
        else
            report_status info "Codex CLI" "would install"
        fi
        return
    fi

    installer="$(mktemp "${TMPDIR:-/tmp}/larry-codex.XXXXXX")" || {
        report_status fail "Codex CLI" "could not create installer file"
        failures=$((failures + 1))
        return
    }

    if ! curl -fsSL "$CODEX_INSTALLER_URL" -o "$installer"; then
        report_status fail "Codex CLI" "installer download failed"
        failures=$((failures + 1))
        rm -f "$installer"
        return
    fi

    if ! /bin/sh "$installer"; then
        report_status fail "Codex CLI" "installation failed"
        failures=$((failures + 1))
        rm -f "$installer"
        return
    fi

    rm -f "$installer"

    if codex_command="$(resolve_codex_command)"; then
        report_status ok "Codex CLI" \
            "$("$codex_command" --version 2>/dev/null | head -n 1)"
    else
        report_status fail "Codex CLI" "command unavailable after install"
        failures=$((failures + 1))
    fi
}

install_codex_extension() {
    local code_command

    if ! code_command="$(resolve_code_command)"; then
        report_status fail "Codex extension" "VS Code command unavailable"
        failures=$((failures + 1))
        return
    fi

    if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
        if extension_installed "$code_command"; then
            report_status ok "Codex extension" "installed"
        else
            report_status info "Codex extension" "would install"
        fi
        return
    fi

    if "$code_command" --install-extension "$CODEX_EXTENSION" --force; then
        if extension_installed "$code_command"; then
            report_status ok "Codex extension" "installed"
        else
            report_status fail "Codex extension" "missing after install"
            failures=$((failures + 1))
        fi
    else
        report_status fail "Codex extension" "installation failed"
        failures=$((failures + 1))
    fi
}

larry_section "OpenAI Codex"

install_codex_cli
install_codex_extension

report_status info "First use" "sign in with ChatGPT"
report_status info \
    "VS Code sidebar" \
    "Command Palette: Codex: Open Codex Sidebar"

if (( failures == 0 )); then
    report_status ok "Status" "COMPLETE"
else
    report_status fail "Status" "$failures failure(s)"
fi

larry_info "Codex report: $REPORT_FILE"

exit 0
