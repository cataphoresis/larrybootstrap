#!/usr/bin/env bash

DOWNLOAD_DIR="$HOME/Downloads/Linux-Installers"

is_macbook_xfce_profile() {
    local product_name=""
    local desktop="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"

    if [[ -r /sys/class/dmi/id/product_name ]]; then
        read -r product_name < /sys/class/dmi/id/product_name
    fi

    [[ "$product_name" == "MacBook9,1" ]] || return 1

    [[ "${desktop,,}" == *xfce* ]] || command -v xfce4-session >/dev/null 2>&1
}

is_current_xfce_graphical_session() {
    local desktop="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"

    [[ -n "${DISPLAY:-}" && "${desktop,,}" == *xfce* ]]
}

configure_mac_keyboard_compatibility() {
    if ! is_macbook_xfce_profile; then
        echo "MacBook9,1 with XFCE not detected; skipping Mac keyboard mappings."
        return
    fi

    section "Configuring MacBook keyboard compatibility"

    local bin_dir="$HOME/.local/bin"
    local autostart_dir="$HOME/.config/autostart"
    local xbindkeys_config="$HOME/.xbindkeysrc"
    local config_temp

    mkdir -p "$bin_dir" "$autostart_dir"

    install -m 0755 /dev/stdin "$bin_dir/mac-copy-paste" <<'EOF'
#!/usr/bin/env bash
set -u

action="${1:-}"
window_id="$(xdotool getwindowfocus 2>/dev/null || true)"
window_class="$(
    xprop -id "$window_id" WM_CLASS 2>/dev/null |
        tr '[:upper:]' '[:lower:]'
)"

xdotool keyup Super_L c v 2>/dev/null || true
sleep 0.08

case "$action" in
    copy)
        if [[ "$window_class" == *xfce4-terminal* ]]; then
            xdotool key ctrl+shift+c
        elif [[ "$window_class" == *\"code\"* ||
                "$window_class" == *\"code-oss\"* ]]; then
            # VS Code handles this through context-aware bindings below. In an
            # integrated terminal it copies only selected text and never sends
            # Ctrl+C (SIGINT) to Codex.
            xdotool key ctrl+shift+c
        else
            xdotool key ctrl+c
        fi
        ;;
    paste)
        if [[ "$window_class" == *xfce4-terminal* ]]; then
            xdotool key ctrl+shift+v
        elif [[ "$window_class" == *\"code\"* ||
                "$window_class" == *\"code-oss\"* ]]; then
            # Shift+Insert asks VS Code or its integrated terminal to paste
            # text instead of forwarding Ctrl+V to Codex's image handler.
            xdotool key shift+Insert
        else
            xdotool key ctrl+v
        fi
        ;;
    select-all)
        xdotool key ctrl+a
        ;;
    *)
        printf 'Usage: %s copy|paste|select-all\n' "$0" >&2
        exit 2
        ;;
esac
EOF

    install -m 0755 /dev/stdin "$bin_dir/mac-window-switch" <<'EOF'
#!/usr/bin/env bash
set -u

direction="${1:-next}"

xdotool keyup Super_L Super_R Shift_L Shift_R Tab 2>/dev/null || true
sleep 0.05

desktop="$(xdotool get_desktop)"
active="$(xdotool getactivewindow 2>/dev/null || true)"

mapfile -t windows < <(
    xdotool search --onlyvisible --desktop "$desktop" "" 2>/dev/null
)

if (( ${#windows[@]} < 2 )); then
    exit 0
fi

current=-1

for i in "${!windows[@]}"; do
    if [[ "${windows[$i]}" == "$active" ]]; then
        current="$i"
        break
    fi
done

case "$direction" in
    next)
        if (( current < 0 )); then
            target=0
        else
            target=$(( (current + 1) % ${#windows[@]} ))
        fi
        ;;
    previous)
        if (( current < 0 )); then
            target=$((${#windows[@]} - 1))
        else
            target=$(( (current - 1 + ${#windows[@]}) % ${#windows[@]} ))
        fi
        ;;
    *)
        printf 'Usage: %s next|previous\n' "$0" >&2
        exit 2
        ;;
esac

xdotool windowactivate --sync "${windows[$target]}"
EOF

    config_temp="$(mktemp)"

    if [[ -f "$xbindkeys_config" ]]; then
        awk '
            /^# BEGIN LarryBootstrap Mac keyboard bindings$/ { managed=1; next }
            /^# END LarryBootstrap Mac keyboard bindings$/ { managed=0; next }
            !managed { print }
        ' "$xbindkeys_config" > "$config_temp"
    fi

    if [[ -s "$config_temp" ]]; then
        printf '\n' >> "$config_temp"
    fi

    cat >> "$config_temp" <<EOF
# BEGIN LarryBootstrap Mac keyboard bindings
# Physical Command is Super_L (keycode 133) on the MacBook9,1 X11 keyboard.
# The validated letter keycodes avoid layout-dependent symbolic ambiguity.
"$bin_dir/mac-copy-paste copy"
    m:0x40 + c:54
"$bin_dir/mac-copy-paste paste"
    m:0x40 + c:55
"$bin_dir/mac-copy-paste select-all"
    m:0x40 + c:38
# Symbolic Tab bindings let X11 resolve the Tab keycode and Shift modifier.
"$bin_dir/mac-window-switch next"
    Mod4 + Tab
"$bin_dir/mac-window-switch previous"
    Shift + Mod4 + Tab
# END LarryBootstrap Mac keyboard bindings
EOF

    mv "$config_temp" "$xbindkeys_config"
    chmod 0644 "$xbindkeys_config"

    install -m 0644 /dev/stdin "$autostart_dir/xbindkeys.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=xbindkeys
Comment=LarryBootstrap MacBook keyboard compatibility
Exec=/usr/bin/xbindkeys --nodaemon
OnlyShowIn=XFCE;
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF

    success "Installed MacBook copy, paste, select-all, and window-switch mappings"

    if is_current_xfce_graphical_session; then
        pkill -x -u "$(id -u)" xbindkeys 2>/dev/null || true

        if xbindkeys; then
            success "Reloaded xbindkeys for the current XFCE session"
        else
            warning "Could not start xbindkeys; it will retry at the next XFCE login"
        fi
    else
        echo "xbindkeys will start at the next XFCE login."
    fi
}

download_verified_file() {
    local url="$1"
    local destination="$2"
    local expected_sha256="$3"

    if [[ -f "$destination" ]] &&
       printf '%s  %s\n' "$expected_sha256" "$destination" |
           sha256sum --check --status; then
        echo "Using verified cache: $destination"
        return 0
    fi

    if [[ -f "$destination" ]]; then
        warning "Cached download failed checksum validation: $destination"
        rm -f "$destination"
    fi

    curl --fail --location --retry 3 "$url" --output "$destination" || return 1

    printf '%s  %s\n' "$expected_sha256" "$destination" |
        sha256sum --check --status
}

xfconf_set() {
    local channel="$1"
    local property="$2"
    local type="$3"
    local value="$4"

    xfconf-query -c "$channel" -p "$property" -s "$value" 2>/dev/null ||
        xfconf-query -c "$channel" -p "$property" -n -t "$type" -s "$value"
}

configure_xfce_desktop() {
    if ! is_macbook_xfce_profile; then
        echo "MacBook9,1 with XFCE not detected; skipping XFCE appearance."
        return
    fi

    section "Configuring XFCE appearance"

    local theme_version="2025-08-17"
    local icon_version="2025-02-15"
    local theme_archive="$DOWNLOAD_DIR/qogir-theme-$theme_version.tar.gz"
    local icon_archive="$DOWNLOAD_DIR/qogir-icons-$icon_version.tar.gz"
    local extract_dir
    local gtk_css="$HOME/.config/gtk-3.0/gtk.css"
    local css_temp
    local theme_marker="$HOME/.themes/.larrybootstrap-qogir-version"
    local icon_marker="$HOME/.local/share/icons/.larrybootstrap-qogir-version"
    local panel_config="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"

    mkdir -p "$DOWNLOAD_DIR" "$HOME/.themes" "$HOME/.local/share/icons"
    mkdir -p "$(dirname "$gtk_css")"

    download_verified_file \
        "https://github.com/vinceliuice/Qogir-theme/archive/refs/tags/$theme_version.tar.gz" \
        "$theme_archive" \
        "cc7a1a6f7449571251bbfd338e3e671254ba93bee41c5b997bf5a6626faaae8f" || {
        failure "Could not download the verified Qogir GTK theme"
        return
    }

    download_verified_file \
        "https://github.com/vinceliuice/Qogir-icon-theme/archive/refs/tags/$icon_version.tar.gz" \
        "$icon_archive" \
        "b0d07cad5601e0341a53a62df0ed111823b75fc38741d435486620a59fb239ee" || {
        failure "Could not download the verified Qogir icon theme"
        return
    }

    extract_dir="$(mktemp -d)"

    if [[ ! -f "$theme_marker" ]] ||
       [[ "$(< "$theme_marker")" != "$theme_version" ]]; then
        tar -xzf "$theme_archive" -C "$extract_dir"

        if ! bash "$extract_dir/Qogir-theme-$theme_version/install.sh" \
            --dest "$HOME/.themes" --theme default --color light; then
            rm -rf "$extract_dir"
        failure "Could not install the Qogir-Light GTK theme"
            return
        fi

        printf '%s\n' "$theme_version" > "$theme_marker"
    else
        echo "Qogir-Light $theme_version is already installed."
    fi

    if [[ ! -f "$icon_marker" ]] ||
       [[ "$(< "$icon_marker")" != "$icon_version" ]]; then
        tar -xzf "$icon_archive" -C "$extract_dir"

        if ! bash "$extract_dir/Qogir-icon-theme-$icon_version/install.sh" \
            --dest "$HOME/.local/share/icons" --theme default --color standard; then
            rm -rf "$extract_dir"
            failure "Could not install the Qogir icon theme"
            return
        fi

        printf '%s\n' "$icon_version" > "$icon_marker"
    else
        echo "Qogir icons $icon_version are already installed."
    fi

    rm -rf "$extract_dir"

    css_temp="$(mktemp)"
    if [[ -f "$gtk_css" ]]; then
        awk '
            /^\/\* BEGIN LarryBootstrap XFCE appearance \*\/$/ { managed=1; next }
            /^\/\* END LarryBootstrap XFCE appearance \*\/$/ { managed=0; next }
            !managed { print }
        ' "$gtk_css" > "$css_temp"
    fi

    if [[ -s "$css_temp" ]]; then
        printf '\n' >> "$css_temp"
    fi

    cat >> "$css_temp" <<'EOF'
/* BEGIN LarryBootstrap XFCE appearance */
/* Adapted from LinuxScoop's Whisker Menu dark CSS, OpenDesktop 1732225. */
.xfce4-panel.panel {
  background-color: #32343d;
  font-weight: normal;
  text-shadow: none;
  -gtk-icon-shadow: none;
}

.xfce4-panel.panel button.flat {
  color: #e6ebef;
  border: 0;
  border-radius: 4px;
  background-color: rgba(50, 52, 61, 0.95);
}

.xfce4-panel.panel button.flat:hover {
  background-color: #494c59;
}

#whiskermenu-window {
  color: #e6ebef;
  background-color: rgba(50, 52, 61, 0.96);
  border-radius: 10px 10px 0 0;
}

#whiskermenu-window entry {
  color: #e6ebef;
  background-color: rgba(0, 0, 0, 0.25);
}

#whiskermenu-window button,
#whiskermenu-window treeview {
  color: #e6ebef;
  background-color: transparent;
  border: 0;
  border-radius: 5px;
}

#whiskermenu-window button:hover,
#whiskermenu-window button:focus,
#whiskermenu-window treeview:selected {
  color: #ffffff;
  background-color: #5294e2;
}
/* END LarryBootstrap XFCE appearance */
EOF
    mv "$css_temp" "$gtk_css"

    if [[ -f "$panel_config" &&
          ! -f "$panel_config.larrybootstrap-backup" ]]; then
        cp -p "$panel_config" "$panel_config.larrybootstrap-backup"
        success "Backed up the original XFCE panel configuration"
    fi

    if ! is_current_xfce_graphical_session; then
        warning "XFCE assets installed; log into XFCE to apply panel settings"
        return
    fi

    xfconf_set xsettings /Net/ThemeName string Qogir-Light
    xfconf_set xsettings /Net/IconThemeName string Qogir
    xfconf_set xsettings /Gtk/FontName string "Inter 10"
    xfconf_set xsettings /Xft/DPI int 144
    xfconf_set xfwm4 /general/theme string Qogir-Light

    xfconf-query -c xfce4-panel -p /panels/panel-2 -r -R 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels -t int -s 1 -a
    xfconf_set xfce4-panel /panels/panel-1/position string "p=10;x=0;y=0"
    xfconf_set xfce4-panel /panels/panel-1/size uint 34
    xfconf_set xfce4-panel /plugins/plugin-1 string whiskermenu

    xfce4-panel --restart
    success "Applied Qogir-Light, Qogir icons, one bottom panel, and Whisker Menu"
}

configure_xfce_panel_layout() {
    if ! is_macbook_xfce_profile; then
        echo "MacBook9,1 with XFCE not detected; skipping final XFCE panel layout."
        return
    fi

    section "Applying final XFCE panel layout"

    if ! is_current_xfce_graphical_session; then
        warning "Final XFCE panel layout requires a live XFCE session; rerun full mode after login"
        return
    fi

    local panel_dir="$HOME/.config/xfce4/panel"
    local plugin_id
    local desktop_file
    local item
    local -a plugin_ids=(101 102 103 104 105 106)
    local -a desktop_files=(
        /usr/share/applications/code.desktop
        /usr/share/applications/xfce4-terminal.desktop
        /usr/share/applications/firefox-esr.desktop
        /usr/share/applications/1password.desktop
        /usr/share/applications/thunar.desktop
        "$HOME/.local/share/applications/Balatro.desktop"
    )

    mkdir -p "$panel_dir" "$HOME/.local/share/applications"

    if [[ ! -f "${desktop_files[5]}" ]]; then
        install -m 0644 /dev/stdin "${desktop_files[5]}" <<'EOF'
[Desktop Entry]
Name=Balatro
Comment=Play this game on Steam
Exec=steam steam://rungameid/2379780
Icon=steam_icon_2379780
Terminal=false
Type=Application
Categories=Game;
EOF
    fi

    for plugin_id in "${plugin_ids[@]}"; do
        xfconf-query -c xfce4-panel -p "/plugins/plugin-$plugin_id" -r -R \
            2>/dev/null || true
        rm -rf "$panel_dir/launcher-$plugin_id"
    done

    for ((item = 0; item < ${#plugin_ids[@]}; item++)); do
        plugin_id="${plugin_ids[$item]}"
        desktop_file="${desktop_files[$item]}"

        if [[ ! -f "$desktop_file" ]]; then
            warning "Quick-launch application is unavailable: $desktop_file"
            return
        fi

        mkdir -p "$panel_dir/launcher-$plugin_id"
        cp "$desktop_file" "$panel_dir/launcher-$plugin_id/$(basename "$desktop_file")"
        xfconf-query -c xfce4-panel -p "/plugins/plugin-$plugin_id" \
            -n -t string -s launcher
        xfconf-query -c xfce4-panel -p "/plugins/plugin-$plugin_id/items" \
            -n -a -t string -s "$(basename "$desktop_file")"
    done

    xfconf_set xfce4-panel /plugins/plugin-1 string whiskermenu
    xfconf_set xfce4-panel /plugins/plugin-2 string tasklist
    xfconf_set xfce4-panel /plugins/plugin-3 string separator
    xfconf_set xfce4-panel /plugins/plugin-4 string pager
    xfconf_set xfce4-panel /plugins/plugin-5 string separator
    xfconf_set xfce4-panel /plugins/plugin-6 string systray
    xfconf_set xfce4-panel /plugins/plugin-7 string separator
    xfconf_set xfce4-panel /plugins/plugin-8 string clock
    xfconf_set xfce4-panel /plugins/plugin-9 string separator
    xfconf_set xfce4-panel /plugins/plugin-10 string actions
    xfconf_set xfce4-panel /plugins/plugin-3/expand bool true
    xfconf_set xfce4-panel /panels/panel-1/size uint 46
    xfconf_set xfce4-panel /panels/panel-1/icon-size uint 40

    xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids \
        -t int -s 1 \
        -t int -s 101 -t int -s 102 -t int -s 103 \
        -t int -s 104 -t int -s 105 -t int -s 106 \
        -t int -s 2 -t int -s 3 -t int -s 4 -t int -s 5 \
        -t int -s 6 -t int -s 7 -t int -s 8 -t int -s 9 \
        -t int -s 10

    xfce4-panel --restart
    success "Applied 40-pixel quick launchers and the shared cross-OS panel layout"
}

configure_vscode_codex() {
    section "Configuring Visual Studio Code for Codex"

    if ! command -v code >/dev/null 2>&1; then
        warning "Skipping VS Code configuration: code is unavailable"
        return
    fi

    local user_dir="$HOME/.config/Code/User"
    local settings="$user_dir/settings.json"
    local keybindings="$user_dir/keybindings.json"
    local temp

    mkdir -p "$user_dir"

    run_step "Install the official OpenAI Codex extension" \
        code --install-extension openai.chatgpt --force

    temp="$(mktemp)"
    if ! jq '
        . + {
            "workbench.colorTheme": "Default Dark Modern",
            "editor.fontFamily": "Fira Code, monospace",
            "editor.fontLigatures": true,
            "editor.fontSize": 14,
            "terminal.integrated.fontFamily": "Fira Code",
            "terminal.integrated.fontSize": 13,
            "terminal.integrated.copyOnSelection": false
        }
    ' "${settings:-/dev/null}" > "$temp" 2>/dev/null; then
        printf '{}\n' | jq '
            . + {
                "workbench.colorTheme": "Default Dark Modern",
                "editor.fontFamily": "Fira Code, monospace",
                "editor.fontLigatures": true,
                "editor.fontSize": 14,
                "terminal.integrated.fontFamily": "Fira Code",
                "terminal.integrated.fontSize": 13,
                "terminal.integrated.copyOnSelection": false
            }
        ' > "$temp"
    fi
    mv "$temp" "$settings"

    temp="$(mktemp)"
    if [[ -f "$keybindings" ]] && jq -e 'type == "array"' "$keybindings" >/dev/null 2>&1; then
        jq '
            map(select(
                (.command != "workbench.action.terminal.paste" or
                 (.key != "ctrl+v" and .key != "ctrl+shift+v" and
                  .key != "shift+insert")) and
                (.key != "ctrl+shift+c" or
                 (.command != "workbench.action.terminal.copySelection" and
                  .command != "editor.action.clipboardCopyAction"))
            )) +
            [
                {"key":"ctrl+shift+c","command":"workbench.action.terminal.copySelection","when":"terminalFocus"},
                {"key":"ctrl+shift+c","command":"editor.action.clipboardCopyAction","when":"editorTextFocus"},
                {"key":"ctrl+v","command":"workbench.action.terminal.paste","when":"terminalFocus"},
                {"key":"ctrl+shift+v","command":"workbench.action.terminal.paste","when":"terminalFocus"},
                {"key":"shift+insert","command":"workbench.action.terminal.paste","when":"terminalFocus"}
            ]
        ' "$keybindings" > "$temp"
    else
        cat > "$temp" <<'EOF'
[
  {"key":"ctrl+shift+c","command":"workbench.action.terminal.copySelection","when":"terminalFocus"},
  {"key":"ctrl+shift+c","command":"editor.action.clipboardCopyAction","when":"editorTextFocus"},
  {"key":"ctrl+v","command":"workbench.action.terminal.paste","when":"terminalFocus"},
  {"key":"ctrl+shift+v","command":"workbench.action.terminal.paste","when":"terminalFocus"},
  {"key":"shift+insert","command":"workbench.action.terminal.paste","when":"terminalFocus"}
]
EOF
    fi
    mv "$temp" "$keybindings"

    success "Configured VS Code terminal copy and paste for Codex"
}

install_codex_cli() {
    section "OpenAI Codex CLI"

    if ! command -v node >/dev/null 2>&1 ||
       ! command -v npm >/dev/null 2>&1; then
        failure "Cannot install Codex CLI: Node.js and npm are required"
        return
    fi

    run_step "Install the official OpenAI Codex CLI" \
        sudo npm install --global --no-audit --no-fund @openai/codex@latest
}

configure_flatpak() {
    section "Configuring Flatpak"

    mkdir -p "$DOWNLOAD_DIR"

    if flatpak remote-list --columns=name \
        2>/dev/null | grep -qx flathub; then
        echo "Flathub is already configured."
    else
        run_step "Add the Flathub repository" \
            flatpak remote-add --if-not-exists \
            flathub \
            https://flathub.org/repo/flathub.flatpakrepo
    fi
}

install_heroic() {
    section "Heroic Games Launcher"

    if flatpak info com.heroicgameslauncher.hgl \
        >/dev/null 2>&1; then
        echo "Heroic is already installed."
        return
    fi

    run_step "Install Heroic from Flathub" \
        flatpak install -y flathub com.heroicgameslauncher.hgl
}

validate_deb_archive() {
    local file="$1"

    [[ -f "$file" ]] || return 1
    dpkg-deb --info "$file" >/dev/null 2>&1
}

validate_github_asset_cache() {
    local file="$1"
    local expected_size="$2"
    local expected_digest="$3"

    [[ -f "$file" ]] || return 1

    if [[ -n "$expected_size" && "$expected_size" != "null" ]]; then
        if [[ "$(stat -c '%s' "$file")" != "$expected_size" ]]; then
            return 1
        fi
    fi

    if [[ -n "$expected_digest" &&
          "$expected_digest" != "null" &&
          "$expected_digest" == sha256:* ]]; then
        local expected_sha="${expected_digest#sha256:}"
        local actual_sha

        actual_sha="$(
            sha256sum "$file" |
                awk '{print $1}'
        )"

        [[ "$actual_sha" == "$expected_sha" ]] || return 1
    fi

    validate_deb_archive "$file"
}

install_vscode() {
    section "Visual Studio Code"

    if command -v code >/dev/null 2>&1; then
        echo "Visual Studio Code is already installed."
        return
    fi

    mkdir -p "$DOWNLOAD_DIR"

    local metadata
    local version
    local release_url
    local destination

    metadata="$(
        curl --fail --silent --show-error \
            https://update.code.visualstudio.com/api/update/linux-deb-x64/stable/latest
    )" || {
        failure "Could not retrieve Visual Studio Code release metadata"
        return
    }

    version="$(jq -r '.name // empty' <<< "$metadata")"
    release_url="$(jq -r '.url // empty' <<< "$metadata")"

    if [[ -z "$version" || -z "$release_url" ]]; then
        failure "Could not determine the current Visual Studio Code release"
        return
    fi

    destination="$DOWNLOAD_DIR/code_${version}_amd64.deb"

    if [[ -f "$destination" ]]; then
        if validate_deb_archive "$destination"; then
            echo "Using cached Visual Studio Code installer: $destination"
        else
            warning "Cached Visual Studio Code installer is invalid; downloading a fresh copy"
            rm -f "$destination"
        fi
    fi

    if [[ ! -f "$destination" ]]; then
        if ! curl --fail --location --retry 3 \
            "$release_url" \
            --output "$destination"; then
            failure "Could not download Visual Studio Code"
            return
        fi
    fi

    if ! validate_deb_archive "$destination"; then
        failure "Downloaded Visual Studio Code installer failed validation"
        rm -f "$destination"
        return
    fi

    run_step "Install Visual Studio Code $version" \
        sudo apt-get install -y "$destination"
}

install_1password() {
    section "1Password"

    if dpkg-query -W -f='${db:Status-Abbrev}' 1password \
        2>/dev/null | grep -q '^ii'; then
        echo "1Password is already installed."
        return
    fi

    local keyring="/usr/share/keyrings/1password-archive-keyring.gpg"
    local source="/etc/apt/sources.list.d/1password.list"

    if [[ ! -f "$keyring" ]]; then
        curl --fail --silent --show-error \
            https://downloads.1password.com/linux/keys/1password.asc |
            sudo gpg --dearmor --yes --output "$keyring" ||
            {
                failure "Could not install the 1Password signing key"
                return
            }
    fi

    echo \
      "deb [arch=amd64 signed-by=$keyring] https://downloads.1password.com/linux/debian/amd64 stable main" |
      sudo tee "$source" >/dev/null

    sudo apt-get update || {
        failure "Could not refresh the 1Password repository"
        return
    }

    if sudo env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y 1password; then
        success "Installed 1Password"
    else
        warning "1Password configuration failed; attempting package repair"
        sudo dpkg --configure -a || true
        sudo apt-get -f install -y || true
    fi
}

install_spotify() {
    section "Spotify"

    if dpkg-query -W -f='${db:Status-Abbrev}' spotify-client \
        2>/dev/null | grep -q '^ii'; then
        echo "Spotify is already installed from a Debian package."
        return
    fi

    if flatpak info com.spotify.Client >/dev/null 2>&1; then
        echo "Spotify is already installed from Flatpak."
        return
    fi

    if ! command -v flatpak >/dev/null 2>&1; then
        warning "Skipping Spotify: Flatpak is unavailable"
        return
    fi

    if ! flatpak remotes --columns=name 2>/dev/null |
         grep -qx flathub; then
        warning "Skipping Spotify: Flathub is not configured"
        return
    fi

    run_step "Install Spotify from Flathub" \
        flatpak install -y flathub com.spotify.Client
}

flatpak_app_version() {
    local application_id="$1"

    flatpak info "$application_id" 2>/dev/null |
        awk -F': *' '
            /^[[:space:]]*Version:/ {
                print $2
                exit
            }
        '
}

show_application_status() {
    local version
    local source

    section "Application status"

    printf '%-23s %-8s %-27s %-10s\n' \
        "Application" "Status" "Version" "Source"
    printf '%-23s %-8s %-27s %-10s\n' \
        "-----------------------" "--------" \
        "---------------------------" "----------"

    report_app_row() {
        local application="$1"
        local state="$2"
        local app_version="$3"
        local app_source="$4"

        printf '%-23s ' "$application"

        case "$state" in
            ok)
                status_ok
                ;;
            warn)
                status_warn
                ;;
            fail)
                status_fail
                ;;
            *)
                status_info
                ;;
        esac

        printf '  %-27s %-10s\n' "$app_version" "$app_source"
    }

    if version="$(
        dpkg-query -W -f='${Version}' 1password 2>/dev/null
    )"; then
        report_app_row "1Password" ok "$version" "deb"
    else
        report_app_row "1Password" fail "-" "-"
    fi

    if version="$(
        dpkg-query -W -f='${Version}' spotify-client 2>/dev/null
    )"; then
        report_app_row "Spotify" ok "$version" "deb"
    elif flatpak info com.spotify.Client >/dev/null 2>&1; then
        version="$(flatpak_app_version com.spotify.Client)"
        report_app_row "Spotify" ok "${version:--}" "flatpak"
    else
        report_app_row "Spotify" fail "-" "-"
    fi

    if flatpak info com.heroicgameslauncher.hgl >/dev/null 2>&1; then
        version="$(flatpak_app_version com.heroicgameslauncher.hgl)"
        report_app_row "Heroic" ok "${version:--}" "flatpak"
    else
        report_app_row "Heroic" fail "-" "-"
    fi

    if command -v code >/dev/null 2>&1; then
        version="$(code --version 2>/dev/null | head -n1)"
        report_app_row "VS Code" ok "${version:--}" "deb"
    else
        report_app_row "VS Code" fail "-" "-"
    fi

    if command -v node >/dev/null 2>&1; then
        version="$(node --version 2>/dev/null)"
        report_app_row "Node.js" ok "${version:--}" "deb"
    else
        report_app_row "Node.js" fail "-" "-"
    fi

    if command -v npm >/dev/null 2>&1; then
        version="$(npm --version 2>/dev/null)"
        report_app_row "npm" ok "${version:--}" "deb"
    else
        report_app_row "npm" fail "-" "-"
    fi

    if command -v codex >/dev/null 2>&1; then
        version="$(codex --version 2>/dev/null | head -n1)"
        report_app_row "Codex CLI" ok "${version:--}" "npm"
    else
        report_app_row "Codex CLI" fail "-" "-"
    fi

    if version="$(
        dpkg-query -W -f='${Version}' rpi-imager 2>/dev/null
    )"; then
        report_app_row "Raspberry Pi Imager" ok "$version" "deb"
    else
        report_app_row "Raspberry Pi Imager" fail "-" "-"
    fi

    if version="$(
        dpkg-query -W -f='${Version}' balena-etcher 2>/dev/null
    )"; then
        report_app_row "Balena Etcher" ok "$version" "deb"
    else
        report_app_row "Balena Etcher" fail "-" "-"
    fi
}

install_rpi_imager() {
    section "Raspberry Pi Imager"

    if dpkg-query -W -f='${db:Status-Abbrev}' rpi-imager \
        2>/dev/null | grep -q '^ii'; then
        echo "Raspberry Pi Imager is already installed."
        return
    fi

    mkdir -p "$DOWNLOAD_DIR"

    local release_data
    local asset_name
    local release_url
    local asset_size
    local asset_digest
    local destination

    release_data="$(
        curl --fail --silent --show-error \
            https://api.github.com/repos/raspberrypi/rpi-imager/releases/latest
    )" || {
        failure "Could not retrieve Raspberry Pi Imager release metadata"
        return
    }

    asset_name="$(
        jq -r '
            .assets[]
            | select(.name | test("^rpi-imager_[0-9.]+_amd64\\.deb$"))
            | .name
        ' <<< "$release_data" |
        head -n1
    )"

    release_url="$(
        jq -r '
            .assets[]
            | select(.name | test("^rpi-imager_[0-9.]+_amd64\\.deb$"))
            | .browser_download_url
        ' <<< "$release_data" |
        head -n1
    )"

    asset_size="$(
        jq -r '
            .assets[]
            | select(.name | test("^rpi-imager_[0-9.]+_amd64\\.deb$"))
            | .size
        ' <<< "$release_data" |
        head -n1
    )"

    asset_digest="$(
        jq -r '
            .assets[]
            | select(.name | test("^rpi-imager_[0-9.]+_amd64\\.deb$"))
            | .digest
        ' <<< "$release_data" |
        head -n1
    )"

    if [[ -z "$asset_name" || "$asset_name" == "null" ||
          -z "$release_url" || "$release_url" == "null" ]]; then
        warning "Could not determine the current Raspberry Pi Imager Debian package"
        return
    fi

    destination="$DOWNLOAD_DIR/$asset_name"

    if [[ -f "$destination" ]]; then
        if validate_github_asset_cache \
            "$destination" "$asset_size" "$asset_digest"; then
            echo "Using cached Raspberry Pi Imager installer: $destination"
        else
            warning "Cached Raspberry Pi Imager installer failed validation; downloading a fresh copy"
            rm -f "$destination"
        fi
    fi

    if [[ ! -f "$destination" ]]; then
        if ! curl --fail --location --retry 3 \
            "$release_url" \
            --output "$destination"; then
            failure "Could not download Raspberry Pi Imager"
            return
        fi
    fi

    if ! validate_github_asset_cache \
        "$destination" "$asset_size" "$asset_digest"; then
        failure "Downloaded Raspberry Pi Imager installer failed validation"
        rm -f "$destination"
        return
    fi

    run_step "Install Raspberry Pi Imager" \
        sudo apt-get install -y "$destination"
}

install_balena_etcher() {
    section "Balena Etcher"

    if dpkg-query -W -f='${db:Status-Abbrev}' balena-etcher \
        2>/dev/null | grep -q '^ii'; then
        echo "Balena Etcher is already installed."
        return
    fi

    mkdir -p "$DOWNLOAD_DIR"

    local release_data
    local asset_name
    local release_url
    local asset_size
    local asset_digest
    local destination

    release_data="$(
        curl --fail --silent --show-error \
            https://api.github.com/repos/balena-io/etcher/releases/latest
    )" || {
        failure "Could not retrieve Balena Etcher release metadata"
        return
    }

    asset_name="$(
        jq -r '
            .assets[]
            | select(.name | test("^balena-etcher_[0-9.]+_amd64\\.deb$"))
            | .name
        ' <<< "$release_data" |
        head -n1
    )"

    release_url="$(
        jq -r '
            .assets[]
            | select(.name | test("^balena-etcher_[0-9.]+_amd64\\.deb$"))
            | .browser_download_url
        ' <<< "$release_data" |
        head -n1
    )"

    asset_size="$(
        jq -r '
            .assets[]
            | select(.name | test("^balena-etcher_[0-9.]+_amd64\\.deb$"))
            | .size
        ' <<< "$release_data" |
        head -n1
    )"

    asset_digest="$(
        jq -r '
            .assets[]
            | select(.name | test("^balena-etcher_[0-9.]+_amd64\\.deb$"))
            | .digest
        ' <<< "$release_data" |
        head -n1
    )"

    if [[ -z "$asset_name" || "$asset_name" == "null" ||
          -z "$release_url" || "$release_url" == "null" ]]; then
        warning "Could not determine the current Balena Etcher Debian package"
        return
    fi

    destination="$DOWNLOAD_DIR/$asset_name"

    if [[ -f "$destination" ]]; then
        if validate_github_asset_cache \
            "$destination" "$asset_size" "$asset_digest"; then
            echo "Using cached Balena Etcher installer: $destination"
        else
            warning "Cached Balena Etcher installer failed validation; downloading a fresh copy"
            rm -f "$destination"
        fi
    fi

    if [[ ! -f "$destination" ]]; then
        if ! curl --fail --location --retry 3 \
            "$release_url" \
            --output "$destination"; then
            failure "Could not download Balena Etcher"
            return
        fi
    fi

    if ! validate_github_asset_cache \
        "$destination" "$asset_size" "$asset_digest"; then
        failure "Downloaded Balena Etcher installer failed validation"
        rm -f "$destination"
        return
    fi

    run_step "Install Balena Etcher" \
        sudo apt-get install -y "$destination"
}
