#!/usr/bin/env bash
set -euo pipefail
module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/modules"
# shellcheck source=modules/common.sh
source "$module_dir/common.sh"
# shellcheck source=modules/apps.sh
source "$module_dir/apps.sh"
is_current_xfce_graphical_session || { echo 'Run from a live XFCE session.' >&2; exit 1; }
backup_dir="$HOME/.local/state/larrybootstrap/panel-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
xfconf-query -c xfce4-panel -lv > "$backup_dir/live-settings.txt"
cp -a "$HOME/.config/xfce4/panel" "$backup_dir/"
cp -p "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" "$backup_dir/"
configure_xfce_quick_launchers
