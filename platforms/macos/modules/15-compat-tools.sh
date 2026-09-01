#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=modules/common.sh
source "$ROOT_DIR/modules/common.sh"

REPORT_DIR="$ROOT_DIR/reports"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$REPORT_DIR/compat-tools-$TIMESTAMP.txt"

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

ffmpeg_version() {
    ffmpeg -version 2>/dev/null |
        awk 'NR == 1 {print $3; exit}'
}

ffprobe_version() {
    ffprobe -version 2>/dev/null |
        awk 'NR == 1 {print $3; exit}'
}

ytdlp_version() {
    yt-dlp --version 2>/dev/null |
        head -n 1
}

node_version() {
    node --version 2>/dev/null |
        head -n 1
}

codex_version() {
    codex --version 2>/dev/null | head -n 1
}

vscode_extension_installed() {
    code --list-extensions 2>/dev/null |
        awk '
            BEGIN { found = 1 }
            tolower($0) == "openai.chatgpt" { found = 0 }
            END { exit found }
        '
}

install_ffmpeg_tools() {
    local tmp_dir
    local ffmpeg_zip
    local ffprobe_zip

    tmp_dir="$(mktemp -d)"
    ffmpeg_zip="$tmp_dir/ffmpeg.zip"
    ffprobe_zip="$tmp_dir/ffprobe.zip"

    trap 'rm -rf "$tmp_dir"' RETURN

    if ! curl --fail --location \
        https://evermeet.cx/ffmpeg/getrelease/zip \
        --output "$ffmpeg_zip"
    then
        report_status fail "ffmpeg" "download failed"
        failed_count=$((failed_count + 1))
        return
    fi

    if ! curl --fail --location \
        https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip \
        --output "$ffprobe_zip"
    then
        report_status fail "ffprobe" "download failed"
        failed_count=$((failed_count + 1))
        return
    fi

    if ! unzip -q "$ffmpeg_zip" -d "$tmp_dir/ffmpeg"; then
        report_status fail "ffmpeg" "archive extraction failed"
        failed_count=$((failed_count + 1))
        return
    fi

    if ! unzip -q "$ffprobe_zip" -d "$tmp_dir/ffprobe"; then
        report_status fail "ffprobe" "archive extraction failed"
        failed_count=$((failed_count + 1))
        return
    fi

    if ! file "$tmp_dir/ffmpeg/ffmpeg" | grep -q 'Mach-O 64-bit executable x86_64'; then
        report_status fail "ffmpeg" "unexpected binary architecture"
        failed_count=$((failed_count + 1))
        return
    fi

    if ! file "$tmp_dir/ffprobe/ffprobe" | grep -q 'Mach-O 64-bit executable x86_64'; then
        report_status fail "ffprobe" "unexpected binary architecture"
        failed_count=$((failed_count + 1))
        return
    fi

    chmod 755 \
        "$tmp_dir/ffmpeg/ffmpeg" \
        "$tmp_dir/ffprobe/ffprobe"

    if ! "$tmp_dir/ffmpeg/ffmpeg" -version >/dev/null 2>&1; then
        report_status fail "ffmpeg" "downloaded binary failed execution"
        failed_count=$((failed_count + 1))
        return
    fi

    if ! "$tmp_dir/ffprobe/ffprobe" -version >/dev/null 2>&1; then
        report_status fail "ffprobe" "downloaded binary failed execution"
        failed_count=$((failed_count + 1))
        return
    fi

    if sudo install -m 755 \
        "$tmp_dir/ffmpeg/ffmpeg" \
        /usr/local/bin/ffmpeg &&
       sudo install -m 755 \
        "$tmp_dir/ffprobe/ffprobe" \
        /usr/local/bin/ffprobe
    then
        report_status ok "ffmpeg" "$(ffmpeg_version)"
        report_status ok "ffprobe" "$(ffprobe_version)"
        installed_count=$((installed_count + 2))
    else
        report_status fail "FFmpeg tools" "installation failed"
        failed_count=$((failed_count + 1))
    fi
}

install_ytdlp() {
    local tmp_file

    tmp_file="$(mktemp)"

    if ! curl --fail --location \
        https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos \
        --output "$tmp_file"
    then
        report_status fail "yt-dlp" "download failed"
        rm -f "$tmp_file"
        failed_count=$((failed_count + 1))
        return
    fi

    chmod 755 "$tmp_file"

    if ! "$tmp_file" --version >/dev/null 2>&1; then
        report_status fail "yt-dlp" "downloaded binary failed execution"
        rm -f "$tmp_file"
        failed_count=$((failed_count + 1))
        return
    fi

    if sudo install -m 755 "$tmp_file" /usr/local/bin/yt-dlp; then
        report_status ok "yt-dlp" "$(ytdlp_version)"
        installed_count=$((installed_count + 1))
    else
        report_status fail "yt-dlp" "installation failed"
        failed_count=$((failed_count + 1))
    fi

    rm -f "$tmp_file"
}

install_node() {
    local node_release="v22.23.2"
    local node_archive="node-v22.23.2-darwin-x64.tar.gz"
    local node_sha256="58e99022c2ff89395576cc7fd4d98cea24bb68081475d5f88b801ee8729fb026"
    local node_url
    local tmp_dir
    local archive_path
    local source_dir
    local install_root="/usr/local/lib/nodejs"
    local install_dir="$install_root/node-v22.23.2-darwin-x64"
    local executable

    node_url="https://nodejs.org/download/release/$node_release/$node_archive"
    tmp_dir="$(mktemp -d)"
    archive_path="$tmp_dir/$node_archive"
    source_dir="$tmp_dir/node-v22.23.2-darwin-x64"

    trap 'rm -rf "$tmp_dir"' RETURN

    if ! curl --fail --location "$node_url" --output "$archive_path"; then
        report_status fail "node" "download failed"
        failed_count=$((failed_count + 1))
        return
    fi

    if ! printf '%s  %s\n' "$node_sha256" "$archive_path" |
        shasum -a 256 --check --status
    then
        report_status fail "node" "checksum verification failed"
        failed_count=$((failed_count + 1))
        return
    fi

    if ! tar -xzf "$archive_path" -C "$tmp_dir"; then
        report_status fail "node" "archive extraction failed"
        failed_count=$((failed_count + 1))
        return
    fi

    if ! file "$source_dir/bin/node" |
        grep -q 'Mach-O 64-bit executable x86_64'
    then
        report_status fail "node" "unexpected binary architecture"
        failed_count=$((failed_count + 1))
        return
    fi

    if ! "$source_dir/bin/node" --version >/dev/null 2>&1; then
        report_status fail "node" "downloaded binary failed execution"
        failed_count=$((failed_count + 1))
        return
    fi

    if [[ -e "$install_dir" ]]; then
        report_status fail "node" "target install directory already exists"
        failed_count=$((failed_count + 1))
        return
    fi

    if ! sudo mkdir -p "$install_root" ||
       ! sudo cp -R "$source_dir" "$install_dir"
    then
        report_status fail "node" "installation failed"
        failed_count=$((failed_count + 1))
        return
    fi

    for executable in node npm npx corepack; do
        if ! sudo ln -sfn             "$install_dir/bin/$executable"             "/usr/local/bin/$executable"
        then
            report_status fail "node" "command linking failed"
            failed_count=$((failed_count + 1))
            return
        fi
    done

    report_status ok "node" "$("$install_dir/bin/node" --version)"
    installed_count=$((installed_count + 1))
}

report_status info "Profile" "$PROFILE"

if [[ ! -f "$PROFILE_FILE" ]]; then
    report_status fail "Profile" "unknown profile: $PROFILE"
    exit 1
fi

# shellcheck disable=SC1090
source "$PROFILE_FILE"
manual_formula_requested() {
    local requested="$1"
    local formula

    if ! declare -p MANUAL_FORMULAE >/dev/null 2>&1; then
        return 1
    fi

    for formula in "${MANUAL_FORMULAE[@]}"; do
        if [[ "$formula" == "$requested" ]]; then
            return 0
        fi
    done

    return 1
}
section "Compatibility-managed Tools"

if manual_formula_requested ffmpeg; then
if command -v ffmpeg >/dev/null 2>&1; then
    report_status ok "ffmpeg" "$(ffmpeg_version)"
    present_count=$((present_count + 1))
else
    if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
        report_status info "ffmpeg" "would install standalone binary"
    else
        larry_stage "Install standalone FFmpeg tools"
        install_ffmpeg_tools
    fi
fi

if command -v ffprobe >/dev/null 2>&1; then
    report_status ok "ffprobe" "$(ffprobe_version)"
    present_count=$((present_count + 1))
elif command -v ffmpeg >/dev/null 2>&1; then
    report_status warn "ffprobe" "missing while ffmpeg is present"
    warning_guidance+=(
        "ffprobe|ffmpeg is installed but ffprobe is missing.|Reinstall the compatibility FFmpeg tool pair."
    )
fi

fi

if manual_formula_requested yt-dlp; then
if command -v yt-dlp >/dev/null 2>&1; then
    report_status ok "yt-dlp" "$(ytdlp_version)"
    present_count=$((present_count + 1))
else
    if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
        report_status info "yt-dlp" "would install standalone binary"
    else
        larry_stage "Install standalone yt-dlp"
        install_ytdlp
    fi
fi

fi

if manual_formula_requested node; then
    if command -v node >/dev/null 2>&1; then
        report_status ok "node" "$(node_version)"
        present_count=$((present_count + 1))
    else
        if [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
            report_status info "node" "would install official Node 22 binary"
        else
            larry_stage "Install official Node.js 22 LTS"
            install_node
        fi
    fi
fi

if [[ "$PROFILE" == "developer" ]]; then
    section "OpenAI Developer Tools"

    if ! command -v code >/dev/null 2>&1; then
        report_status warn "OpenAI VS Code Extension" "code command unavailable"
        warning_guidance+=(
            "OpenAI VS Code Extension|Visual Studio Code is installed but its code command is unavailable.|Add the Visual Studio Code command-line launcher to PATH, then rerun the bootstrap."
        )
    elif vscode_extension_installed; then
        report_status ok "OpenAI VS Code Extension" "installed"
        present_count=$((present_count + 1))
    elif [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
        report_status info "OpenAI VS Code Extension" "would install openai.chatgpt"
    elif code --install-extension openai.chatgpt; then
        report_status ok "OpenAI VS Code Extension" "installed"
        installed_count=$((installed_count + 1))
    else
        report_status warn "OpenAI VS Code Extension" "installation failed"
        warning_guidance+=(
            "OpenAI VS Code Extension|The openai.chatgpt extension could not be installed.|Run: code --install-extension openai.chatgpt"
        )
    fi

    if command -v codex >/dev/null 2>&1; then
        report_status ok "Codex CLI" "$(codex_version)"
        present_count=$((present_count + 1))
    elif ! command -v npm >/dev/null 2>&1; then
        report_status warn "Codex CLI" "npm unavailable"
        warning_guidance+=(
            "Codex CLI|npm is required to install @openai/codex.|Restore the compatibility-managed Node.js installation, then rerun the bootstrap."
        )
    elif [[ "$MACBOOK_DRY_RUN" == "1" ]]; then
        report_status info "Codex CLI" "would install @openai/codex"
    elif npm install -g @openai/codex &&
         command -v codex >/dev/null 2>&1
    then
        report_status ok "Codex CLI" "$(codex_version)"
        installed_count=$((installed_count + 1))
    else
        report_status warn "Codex CLI" "installation failed"
        warning_guidance+=(
            "Codex CLI|npm could not install @openai/codex globally.|Review npm global-directory permissions, then rerun the bootstrap."
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

section "Compatibility Tools Result"

report_status info "Already present" "$present_count"
report_status info "Newly installed" "$installed_count"

if (( failed_count == 0 )); then
    report_status ok "Failures" "0"
    report_status ok "Status" "COMPLETE"
else
    report_status fail "Failures" "$failed_count"
    report_status fail "Status" "INCOMPLETE"
fi

larry_info "Compatibility report: $REPORT_FILE"

exit 0
