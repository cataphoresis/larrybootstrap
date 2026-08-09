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
    gparted
    exfatprogs
    ntfs-3g
    smartmontools
    lm-sensors
    mesa-utils
    vainfo
    firmware-linux
    firmware-linux-nonfree
    build-essential
    shellcheck
    python3
    python3-pip
    python3-venv
    pipx

    # Lightweight development and text editing
    geany
    geany-plugins
    gh

    # Android Platform Tools and USB permissions
    adb
    fastboot
    android-sdk-platform-tools-common
    usbutils

    # Networking and homelab utilities
    nmap
    iperf3
    tcpdump
    wireshark
    traceroute
    bind9-dnsutils
    ethtool
    whois
    mtr-tiny
    net-tools
)

install_core_packages() {
    install_apt_packages "Installing core packages" \
        "${CORE_PACKAGES[@]}"
}

configure_package_defaults() {
    section "Configuring package defaults"

    local failed=false

    if echo 'iperf3 iperf3/start_daemon boolean false' |
       sudo debconf-set-selections; then
        status_ok
        printf ' %-18s %s\n' "iperf3" "daemon disabled"
    else
        failure "Could not configure iperf3 package default"
        failed=true
    fi

    if echo 'wireshark-common wireshark-common/install-setuid boolean true' |
       sudo debconf-set-selections; then
        status_ok
        printf ' %-18s %s\n' "Wireshark" "non-root capture enabled"
    else
        failure "Could not configure Wireshark package default"
        failed=true
    fi

    if echo 'code code/add-microsoft-repo boolean true' |
       sudo debconf-set-selections; then
        status_ok
        printf ' %-18s %s\n' "VS Code" "Microsoft update repository enabled"
    else
        failure "Could not configure Visual Studio Code package default"
        failed=true
    fi

    if [[ "$failed" == true ]]; then
        return 1
    fi

    success "Configured noninteractive package defaults"
}
install_full_packages() {
    install_apt_packages "Installing full utility set" \
        "${FULL_PACKAGES[@]}"

    if grep -qm1 '^vendor_id[[:space:]]*: GenuineIntel$' /proc/cpuinfo; then
        install_apt_packages "Installing Intel CPU microcode" \
            intel-microcode
    else
        echo "Intel CPU not detected; skipping intel-microcode."
    fi
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

    echo "Autoremove is intentionally not run automatically."
    echo "Packages APT currently considers removable:"

    sudo apt-get -s autoremove --purge 2>/dev/null |
        awk '/^Remv / {print "  " $2}' ||
        true

    run_step "Clean obsolete downloaded packages" \
        sudo apt-get autoclean
}
