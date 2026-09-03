#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=modules/common.sh
source "$ROOT_DIR/modules/common.sh"

REPORT_DIR="$ROOT_DIR/reports"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/homebrew-$TIMESTAMP.txt"

PROFILE="${MACBOOK_PROFILE:-standard}"
PROFILE_FILE="$ROOT_DIR/profiles/$PROFILE.conf"
MACBOOK_DRY_RUN="${MACBOOK_DRY_RUN:-0}"

if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    REPORT_FILE="/dev/null"
else
    mkdir -p "$REPORT_DIR"
fi

installed_count=0
present_count=0
manual_count=0
manual_pending_count=0
skipped_count=0
failed_count=0

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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

formula_has_bottle() {
    local formula="$1"

    brew info --json=v2 --formula "$formula" 2>/dev/null |
        /usr/bin/ruby -rjson -e '
            data = JSON.parse(STDIN.read)
            files = data.fetch("formulae").first
                        .dig("bottle", "stable", "files") || {}
            exit(files.empty? ? 1 : 0)
        '
}

first_formula_without_bottle() {
    local formula="$1"
    local dependency
    local -a candidates=("$formula")

    while IFS= read -r dependency; do
        [[ -n "$dependency" ]] && candidates+=("$dependency")
    done < <(
        brew deps --formula --include-build --missing "$formula" 2>/dev/null
    )

    for dependency in "${candidates[@]}"; do
        if brew list --formula "$dependency" >/dev/null 2>&1; then
            continue
        fi

        if ! formula_has_bottle "$dependency"; then
            printf '%s\n' "$dependency"
            return 0
        fi
    done

    return 1
}

cask_app_path() {
    case "$1" in
        firefox)                  printf '/Applications/Firefox.app\n' ;;
        visual-studio-code)       printf '/Applications/Visual Studio Code.app\n' ;;
        rectangle)                printf '/Applications/Rectangle.app\n' ;;
        1password)                printf '/Applications/1Password.app\n' ;;
        spotify)                  printf '/Applications/Spotify.app\n' ;;
        vlc)                      printf '/Applications/VLC.app\n' ;;
        keka)                     printf '/Applications/Keka.app\n' ;;
        stats)                    printf '/Applications/Stats.app\n' ;;
        moonlight)                printf '/Applications/Moonlight.app\n' ;;
        wireshark-app)            printf '/Applications/Wireshark.app\n' ;;
        balenaetcher)             printf '/Applications/balenaEtcher.app\n' ;;
        private-internet-access)  printf '/Applications/Private Internet Access.app\n' ;;
        handbrake-app)            printf '/Applications/HandBrake.app\n' ;;
        *)                        printf '\n' ;;
    esac
}

app_version() {
    local app_path="$1"
    local version=""

    [[ -d "$app_path" ]] || return 1

    version="$(
        defaults read "$app_path/Contents/Info.plist" \
            CFBundleShortVersionString 2>/dev/null ||
        defaults read "$app_path/Contents/Info" \
            CFBundleShortVersionString 2>/dev/null ||
        true
    )"

    printf '%s\n' "${version:-installed}"
}

section "Homebrew & Applications"

report_status info "Profile" "$PROFILE"

if [[ ! -f "$PROFILE_FILE" ]]; then
    report_status fail "Profile" "unknown profile: $PROFILE"
    exit 1
fi

if ! command_exists brew; then
    report_status info "Homebrew" "not installed"

    if ! command_exists curl; then
        report_status fail "Homebrew" "curl unavailable"
        exit 1
    fi

    larry_stage "Install Homebrew"

    if ! /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    then
        report_status fail "Homebrew" "installation failed"
        exit 1
    fi
fi

if [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! command_exists brew; then
    report_status fail "Homebrew" "unavailable after installation"
    exit 1
fi

report_status ok "Homebrew" "$(brew --version | head -n 1)"
report_status info "Prefix" "$(brew --prefix)"

# shellcheck disable=SC1090
source "$PROFILE_FILE"

section "Homebrew Maintenance"

if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    report_status info "Repository metadata" "unchanged in dry-run"

    outdated_count="$(
        brew outdated --formula --cask 2>/dev/null |
            wc -l |
            tr -d ' '
    )"

    if (( outdated_count > 0 )); then
        report_status info "Outdated packages" "$outdated_count detected"
    else
        report_status ok "Outdated packages" "0"
    fi
else
    if brew update >/dev/null; then
        report_status ok "Repository metadata" "updated"
    else
        report_status warn "Repository metadata" "update failed; using current metadata"
        warning_guidance+=(
            "Repository metadata|Homebrew update failed.|Review network access and Homebrew health before relying on new package metadata."
        )
    fi
fi

section "Formulae"

for formula in "${FORMULAE[@]}"; do
    if brew list --formula "$formula" >/dev/null 2>&1; then
        version="$(
            brew list --versions "$formula" 2>/dev/null |
                awk '{$1=""; sub(/^ /,""); print}'
        )"

        report_status ok "$formula" "${version:-installed}"
        present_count=$((present_count + 1))
        continue
    fi

    if ! brew info --formula "$formula" >/dev/null 2>&1; then
        report_status warn "$formula" "formula unavailable"
        warning_guidance+=(
            "$formula|Formula is unavailable from current Homebrew metadata.|Review package compatibility for this macOS version."
        )
        skipped_count=$((skipped_count + 1))
        continue
    fi

    if bottle_gap="$(first_formula_without_bottle "$formula")"; then
        report_status warn "$formula" "precompiled bottle unavailable"
        warning_guidance+=(
            "$formula|No compatible bottle is available for $bottle_gap.|Use a reviewed official precompiled Intel package or manage this tool manually; automatic source builds are disabled."
        )
        skipped_count=$((skipped_count + 1))
        continue
    fi

    if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
        report_status info "$formula" "would install from bottle"
        continue
    fi

    larry_stage "Install formula: $formula"

    if brew install "$formula"; then
        version="$(
            brew list --versions "$formula" 2>/dev/null |
                awk '{$1=""; sub(/^ /,""); print}'
        )"

        report_status ok "$formula" "${version:-installed}"
        installed_count=$((installed_count + 1))
    else
        report_status fail "$formula" "installation failed"
        failed_count=$((failed_count + 1))
    fi
done

section "Applications"

for cask in "${CASKS[@]}"; do
    app_path="$(cask_app_path "$cask")"

    if [[ -n "$app_path" && -d "$app_path" ]]; then
        version="$(app_version "$app_path")"
        report_status ok "$cask" "$version"
        present_count=$((present_count + 1))
        continue
    fi

    if brew list --cask "$cask" >/dev/null 2>&1; then
        version="$(
            brew list --versions --cask "$cask" 2>/dev/null |
                awk '{$1=""; sub(/^ /,""); print}'
        )"

        report_status ok "$cask" "${version:-installed}"
        present_count=$((present_count + 1))
        continue
    fi

    if ! brew info --cask "$cask" >/dev/null 2>&1; then
        report_status warn "$cask" "cask unavailable or unsupported"
        warning_guidance+=(
            "$cask|Cask is unavailable or unsupported on this host.|Review Monterey compatibility or use a manual installer."
        )
        skipped_count=$((skipped_count + 1))
        continue
    fi

    if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
        report_status info "$cask" "would install"
        continue
    fi

    larry_stage "Install application: $cask"

    if brew install --cask "$cask"; then
        app_path="$(cask_app_path "$cask")"

        if [[ -n "$app_path" && -d "$app_path" ]]; then
            version="$(app_version "$app_path")"
        else
            version="$(
                brew list --versions --cask "$cask" 2>/dev/null |
                    awk '{$1=""; sub(/^ /,""); print}'
            )"
        fi

        report_status ok "$cask" "${version:-installed}"
        installed_count=$((installed_count + 1))
    else
        report_status fail "$cask" "installation failed"
        failed_count=$((failed_count + 1))
    fi
done

if declare -p MANUAL_FORMULAE >/dev/null 2>&1; then
    section "Manual / Compatibility-managed Formulae"

    for formula in "${MANUAL_FORMULAE[@]}"; do
        if command -v "$formula" >/dev/null 2>&1; then
            case "$formula" in
                ffmpeg)
                    version="$(
                        ffmpeg -version 2>&1 |
                            awk 'NR==1 {print $3; exit}'
                    )"
                    ;;
                yt-dlp)
                    version="$(yt-dlp --version 2>/dev/null || echo installed)"
                    ;;
                *)
                    version="$(
                        "$formula" --version 2>&1 |
                            head -n 1
                    )"
                    ;;
            esac

            report_status ok "$formula" "$version"
        else
            report_status info "$formula" "manual handling required"
            manual_pending_count=$((manual_pending_count + 1))
        fi

        manual_count=$((manual_count + 1))
    done
fi

if declare -p MANUAL_APPS >/dev/null 2>&1; then
    section "Manual / Compatibility-managed Applications"

    for app in "${MANUAL_APPS[@]}"; do
        report_status info "$app" "manual handling required"
        manual_count=$((manual_count + 1))
        manual_pending_count=$((manual_pending_count + 1))
    done
fi

section "Cleanup"

if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
    report_status info "Homebrew cleanup" "skipped in dry-run"
else
    if brew cleanup >/dev/null; then
        report_status ok "Homebrew cleanup" "complete"
    else
        report_status warn "Homebrew cleanup" "returned an error"
        warning_guidance+=(
            "Homebrew cleanup|Cleanup returned an error.|Review Homebrew health; installed applications are unaffected."
        )
    fi
fi

if (( ${#warning_guidance[@]} > 0 )); then
    section "Warnings & Actions"

    for item in "${warning_guidance[@]}"; do
        IFS='|' read -r warning_label warning_detail warning_action <<< "$item"

        status_warn
        printf ' %s\n' "$warning_label"
        printf '       %s\n' "$warning_detail"
        printf '       %s\n' "$warning_action"

        {
            printf '[WARN] %s\n' "$warning_label"
            printf '       %s\n' "$warning_detail"
            printf '       %s\n' "$warning_action"
        } >> "$REPORT_FILE"
    done
fi

section "Homebrew Result"

report_status info "Already present" "$present_count"
report_status info "Newly installed" "$installed_count"
report_status info "Compatibility items" "$manual_count"

if (( manual_pending_count == 0 )); then
    report_status ok "Manual action needed" "0"
else
    report_status info "Manual action needed" "$manual_pending_count"
fi

if (( skipped_count == 0 )); then
    report_status ok "Skipped" "0"
else
    report_status warn "Skipped" "$skipped_count"
fi

if (( failed_count == 0 )); then
    report_status ok "Failures" "0"
    report_status ok "Status" "COMPLETE"
else
    report_status fail "Failures" "$failed_count"
    report_status warn "Status" "COMPLETE WITH FAILURES"
fi

larry_info "Homebrew report: $REPORT_FILE"

exit 0
