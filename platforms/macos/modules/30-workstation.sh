#!/usr/bin/env bash
set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON_DIR="$(cd "$ROOT_DIR/../../common" && pwd)"
# shellcheck source=modules/common.sh
source "$ROOT_DIR/modules/common.sh"
# shellcheck disable=SC1091
source "$COMMON_DIR/firefox-policy.sh"
failed=0
larry_section "Mandatory Firefox extensions"
if [[ "${MACBOOK_DRY_RUN:-0}" == 1 ]]; then
    larry_info "Would apply the five shared mandatory Firefox extensions."
elif [[ -d /Applications/Firefox.app ]]; then
    if apply_firefox_policy /Applications/Firefox.app/Contents/Resources/distribution/policies.json \
        "$COMMON_DIR/profiles/firefox.json"; then
        larry_ok "Firefox extension policy installed; restart Firefox to apply."
    else
        larry_fail "Firefox policy failed"
        failed=1
    fi
else
    larry_fail "Firefox must be installed before its policy can be applied"
    failed=1
fi
larry_section "ChatGPT desktop"
major="$(sw_vers -productVersion | cut -d. -f1)"
if (( major >= 14 )); then
    bundle_id="$(defaults read /Applications/ChatGPT.app/Contents/Info CFBundleIdentifier 2>/dev/null || true)"
    if [[ "$bundle_id" == com.openai.codex ]]; then
        larry_ok "Current official ChatGPT desktop is installed"
    elif [[ "${MACBOOK_DRY_RUN:-0}" == 1 ]]; then
        larry_info "Would install official ChatGPT desktop with Homebrew cask chatgpt."
    elif [[ -d /Applications/ChatGPT.app ]]; then
        larry_warn "A different ChatGPT.app exists; move it aside and rerun to install the current desktop app."
        failed=1
    elif brew install --cask chatgpt; then
        larry_ok "ChatGPT installed; open it to sign in."
    else
        larry_fail "ChatGPT installation failed"
        failed=1
    fi
else
    if [[ -d /Applications/MacGPT.app ]]; then
        larry_ok "MacGPT is installed for this older macOS version"
    else
        larry_warn "macOS $major uses the manual MacGPT fallback. Download and place MacGPT.app in Applications:"
        printf '%s\n' 'https://goodsnooze.gumroad.com/l/menugpt'
    fi
fi
larry_section "Amphetamine (manual App Store installation)"
if [[ -d /Applications/Amphetamine.app ]]; then
    larry_ok "Amphetamine is installed"
else
    larry_info "Click the App Store link to download Amphetamine:"
    printf '%s\n' 'https://apps.apple.com/us/app/amphetamine/'
    printf '%s\n' 'https://apps.apple.com/us/app/amphetamine/id937984704'
fi
exit "$failed"
