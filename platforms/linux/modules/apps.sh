#!/usr/bin/env bash

DOWNLOAD_DIR="$HOME/Downloads/Linux-Installers"

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

install_vscode() {
    section "Visual Studio Code"

    if command -v code >/dev/null 2>&1; then
        echo "Visual Studio Code is already installed."
        return
    fi

    local package="$DOWNLOAD_DIR/vscode-latest-amd64.deb"

    mkdir -p "$DOWNLOAD_DIR"

    if curl --fail --location --retry 3 \
        https://update.code.visualstudio.com/latest/linux-deb-x64/stable \
        --output "$package"; then
        run_step "Install Visual Studio Code" \
            sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"
    else
        failure "Could not download Visual Studio Code"
    fi
}

install_parsec() {
    section "Parsec"

    if command -v parsecd >/dev/null 2>&1 ||
       dpkg-query -W parsec >/dev/null 2>&1; then
        echo "Parsec is already installed."
        return
    fi

    local package="$DOWNLOAD_DIR/parsec-linux-amd64.deb"

    mkdir -p "$DOWNLOAD_DIR"

    if curl --fail --location --retry 3 \
        https://builds.parsec.app/package/parsec-linux.deb \
        --output "$package"; then

        if sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"; then
            success "Installed Parsec"
        else
            warning "Parsec did not install cleanly on Debian"
            sudo apt-get -f install -y || true
        fi
    else
        failure "Could not download Parsec"
    fi
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
        echo "Spotify is already installed."
        return
    fi

    if apt-cache show spotify-client >/dev/null 2>&1; then
        run_step "Install Spotify" \
            sudo apt-get install -y spotify-client
    else
        warning "Spotify repository is not currently configured"
    fi
}

install_balena_etcher() {
    section "Balena Etcher"

    mkdir -p "$DOWNLOAD_DIR"

    local destination="$DOWNLOAD_DIR/balenaEtcher-x64.AppImage"
    local release_url

    release_url="$(
        curl --fail --silent --show-error \
            https://api.github.com/repos/balena-io/etcher/releases/latest |
        jq -r '
            .assets[]
            | select(
                (.name | test("x64"; "i"))
                and
                (.name | test("AppImage$"))
              )
            | .browser_download_url
        ' |
        head -n1
    )"

    if [[ -z "$release_url" || "$release_url" == "null" ]]; then
        warning "Could not determine the current Etcher AppImage URL"
        return
    fi

    if curl --fail --location --retry 3 \
        "$release_url" \
        --output "$destination"; then
        chmod +x "$destination"
        success "Downloaded Balena Etcher to $destination"
    else
        failure "Could not download Balena Etcher"
    fi
}
