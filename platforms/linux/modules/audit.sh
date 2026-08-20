#!/usr/bin/env bash

capture_audit() {
    section "Capturing system and boot audit"

    local reports="$PROJECT_DIR/reports/$TIMESTAMP"

    mkdir -p "$reports"
    rm -f "$PROJECT_DIR/reports/latest"
    ln -s "$reports" "$PROJECT_DIR/reports/latest"

    systemd-analyze \
        > "$reports/systemd-analyze.txt" 2>&1 || true

    systemd-analyze blame \
        > "$reports/systemd-blame.txt" 2>&1 || true

    systemd-analyze critical-chain \
        > "$reports/systemd-critical-chain.txt" 2>&1 || true

    systemctl list-unit-files --state=enabled \
        > "$reports/enabled-services.txt" 2>&1 || true

    systemctl --failed \
        > "$reports/failed-services.txt" 2>&1 || true

    journalctl -b -p warning --no-pager \
        > "$reports/boot-warnings.txt" 2>&1 || true

    journalctl -b --no-pager \
        > "$reports/current-boot-journal.txt" 2>&1 || true

    dpkg-query \
        -W \
        -f='${binary:Package}\t${Installed-Size}\n' |
        sort -k2,2n \
        > "$reports/packages-by-size-kb.txt"

    dpkg-query \
        -W \
        -f='${binary:Package}\t${db:Status-Abbrev}\t${Version}\n' \
        > "$reports/installed-packages.txt"

    lsblk \
        -o NAME,SIZE,FSTYPE,FSVER,LABEL,MOUNTPOINTS,UUID \
        > "$reports/storage.txt"

    df -hT \
        > "$reports/filesystems.txt"

    free -h \
        > "$reports/memory.txt"

    lspci -nnk \
        > "$reports/pci.txt" 2>&1 || true

    lsusb \
        > "$reports/usb.txt" 2>&1 || true

    uname -a \
        > "$reports/kernel.txt"

    systemctl status ssh --no-pager \
        > "$reports/ssh-status.txt" 2>&1 || true

    flatpak list \
        > "$reports/flatpaks.txt" 2>&1 || true


    {
        cat /etc/os-release
        echo
        uname -a
    } > "$reports/os-release.txt"

    {
        printf 'dpkg architecture: %s\n' "$(dpkg --print-architecture)"
        printf 'machine architecture: %s\n' "$(uname -m)"
    } > "$reports/architecture.txt"

    {
        echo "=== dpkg --audit ==="
        dpkg --audit || true
        echo
        echo "=== apt-get check ==="
        apt-get -o Debug::NoLocking=1 check || true
    } > "$reports/apt-health.txt" 2>&1

    apt list --upgradable 2>/dev/null \
        > "$reports/pending-upgrades.txt" || true

    {
        echo "=== addresses ==="
        ip -brief address
        echo
        echo "=== routes ==="
        ip route
    } > "$reports/network.txt" 2>&1

    {
        printf 'enabled: '
        systemctl is-enabled ssh 2>&1 || true
        printf 'active: '
        systemctl is-active ssh 2>&1 || true
        printf 'user-ed25519-key: '
        if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
            echo "present"
        else
            echo "absent"
        fi
    } > "$reports/ssh-summary.txt"

    flatpak remotes --columns=name,url \
        > "$reports/flatpak-remotes.txt" 2>&1 || true

    {
        if id -nG "$USER" | tr ' ' '\n' | grep -qx wireshark; then
            echo "Wireshark capture access enabled for user."
            echo "A re-login may be required if group membership was added recently."
        else
            echo "User is not currently a member of the wireshark group."
        fi
    } > "$reports/wireshark-access.txt"

    apt-get -o Debug::NoLocking=1 -s autoremove --purge 2>&1 |
        tee "$reports/autoremove-simulation.txt" >/dev/null || true

    capture_mac_keyboard_audit "$reports"

    success "Created audit report: $(display_path "$reports")"
}

capture_mac_keyboard_audit() {
    local reports="$1"
    local report="$reports/mac-keyboard-compatibility.txt"
    local helper
    local command_name
    local package
    local binding

    {
        if ! is_macbook_xfce_profile; then
            echo "NOT APPLICABLE: MacBook9,1 with XFCE was not detected."
            return
        fi

        for command_name in xbindkeys xdotool xprop; do
            if command -v "$command_name" >/dev/null 2>&1; then
                echo "PASS: command available: $command_name"
            else
                echo "FAIL: command unavailable: $command_name"
            fi
        done

        for package in xbindkeys xdotool x11-utils; do
            if dpkg-query -W -f='${db:Status-Abbrev}' "$package" \
                2>/dev/null | grep -q '^ii'; then
                echo "PASS: package installed: $package"
            else
                echo "FAIL: package not installed: $package"
            fi
        done

        for helper in mac-copy-paste mac-window-switch; do
            if [[ -x "$HOME/.local/bin/$helper" ]]; then
                echo "PASS: helper is executable: ~/.local/bin/$helper"
            else
                echo "FAIL: helper missing or not executable: ~/.local/bin/$helper"
            fi
        done

        for binding in \
            'm:0x40 + c:54' \
            'm:0x40 + c:55' \
            'm:0x40 + c:38' \
            'Mod4 + Tab' \
            'Shift + Mod4 + Tab'; do
            if grep -Fq "$binding" "$HOME/.xbindkeysrc" 2>/dev/null; then
                echo "PASS: xbindkeys binding present: $binding"
            else
                echo "FAIL: xbindkeys binding missing: $binding"
            fi
        done

        if is_current_xfce_graphical_session; then
            if pgrep -x -u "$(id -u)" xbindkeys >/dev/null 2>&1; then
                echo "PASS: xbindkeys is running in the XFCE graphical session"
            else
                echo "FAIL: xbindkeys is not running in the XFCE graphical session"
            fi
        else
            echo "INFO: xbindkeys process check skipped outside an XFCE graphical session"
        fi
    } > "$report"
}
