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
