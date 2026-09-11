#!/usr/bin/env bash

install_tailscale() {
    section "Tailscale"
    local temporary
    temporary="$(mktemp -d)" || return 1
    # Official Debian 13 repository. Download completely before installing files.
    if ! curl --fail --silent --show-error --location --connect-timeout 15 \
        --max-time 120 https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg \
        -o "$temporary/keyring.gpg" ||
       ! curl --fail --silent --show-error --location --connect-timeout 15 \
        --max-time 120 https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list \
        -o "$temporary/tailscale.list"; then
        rm -rf "$temporary"
        failure "Could not download the Tailscale repository configuration"
        return 1
    fi
    if ! sudo install -m 0644 "$temporary/keyring.gpg" \
        /usr/share/keyrings/tailscale-archive-keyring.gpg ||
       ! sudo install -m 0644 "$temporary/tailscale.list" \
        /etc/apt/sources.list.d/tailscale.list; then
        rm -rf "$temporary"
        failure "Could not configure the Tailscale repository"
        return 1
    fi
    rm -rf "$temporary"
    if ! sudo apt-get update ||
       ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y tailscale; then
        failure "Could not install Tailscale"
        return 1
    fi
    if ! sudo systemctl enable --now tailscaled; then
        failure "Could not start Tailscale"
        return 1
    fi
    success "Tailscale installed and service enabled"
    echo "For first-time sign-in, run: sudo tailscale up"
    echo "Existing Tailscale account, routing, DNS, and SSH settings are retained."
}
