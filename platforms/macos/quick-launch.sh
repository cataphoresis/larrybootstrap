#!/usr/bin/env bash
# Focused Dock setup; run as the desktop user after installing the applications.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS required.' >&2; exit 1; }
command -v dockutil >/dev/null || {
    echo 'Install dockutil from https://github.com/kcrawford/dockutil/releases and rerun.' >&2
    exit 1
}
apps=(
    '/Applications/Firefox.app'
    '/Applications/Visual Studio Code.app'
    '/System/Applications/Utilities/Terminal.app'
    '/Applications/CotEditor.app'
    '/Applications/FileZilla.app'
    '/Applications/1Password.app'
    '/Applications/Spotify.app'
    "$HOME/Applications/Balatro.app"
)
if [[ ! -d "${apps[7]}" ]]; then
    apps[7]="$HOME/Library/Application Support/Steam/steamapps/common/Balatro/Balatro.app"
fi
missing=0
for app in "${apps[@]}"; do
    if [[ ! -d "$app" ]]; then
        printf 'Missing application: %s\n' "$app" >&2
        missing=1
    fi
done
[[ "$missing" == 0 ]] || exit 1
backup_dir="$HOME/Library/Application Support/LarryBootstrap"
mkdir -p "$backup_dir"
defaults export com.apple.dock "$backup_dir/dock-$(date +%Y%m%d-%H%M%S).plist"
# Finder remains the built-in first icon. Keep unrelated pins after our apps.
position=1
for app in "${apps[@]}"; do
    dockutil --add "$app" --replacing "$(basename "$app" .app)" --no-restart
    dockutil --move "$(basename "$app" .app)" --position "$position" --no-restart
    position=$((position + 1))
done
defaults write com.apple.dock orientation -string bottom
defaults write com.apple.dock tilesize -int 48
killall Dock
