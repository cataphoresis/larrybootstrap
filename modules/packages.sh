#!/usr/bin/env bash

CORE_PACKAGES=(
    ca-certificates
    curl
    wget
    gnupg
    jq
    git
    rsync
    unzip
    zip
    p7zip-full
    file-roller
    firefox-esr
    vlc
    ffmpeg
    mediainfo
    flatpak
    openssh-client
    openssh-server
    htop
    btop
    ncdu
    tree
    lsof
    tmux
    screen
)

FULL_PACKAGES=(
    steam-installer
    rpi-imager
    gparted
    exfatprogs
    ntfs-3g
    smartmontools
    lm-sensors
    mesa-utils
    vainfo
    intel-microcode
    firmware-linux
    firmware-linux-nonfree
    build-essential
    shellcheck
    python3
    python3-pip
    python3-venv
    pipx
    nmap
    iperf3
    tcpdump
    wireshark
    traceroute
    dnsutils
    ethtool
    whois
    mtr-tiny
    net-tools
)

install_core_packages() {
    install_apt_packages "Installing core packages" \
        "${CORE_PACKAGES[@]}"
}

install_full_packages() {
    install_apt_packages "Installing full utility set" \
        "${FULL_PACKAGES[@]}"
}

configure_user_groups() {
    section "Configuring user groups"

    local groups=(
        audio
        video
        render
        plugdev
        dialout
    )

    local group

    for group in "${groups[@]}"; do
        if getent group "$group" >/dev/null; then
            sudo usermod -aG "$group" "$USER"
        fi
    done

    if getent group wireshark >/dev/null; then
        sudo usermod -aG wireshark "$USER"
    fi

    success "Configured hardware and networking groups"
}

enable_trim() {
    section "SSD maintenance"

    if systemctl list-unit-files fstrim.timer \
        2>/dev/null | grep -q fstrim.timer; then
        run_step "Enable periodic filesystem TRIM" \
            sudo systemctl enable --now fstrim.timer
    else
        warning "fstrim.timer is unavailable"
    fi
}

safe_package_cleanup() {
    section "Safe package cleanup"

    run_step "Remove unused dependency packages" \
        sudo apt-get autoremove --purge -y

    run_step "Clean obsolete downloaded packages" \
        sudo apt-get autoclean
}
