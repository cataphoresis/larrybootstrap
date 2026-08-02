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

    success "Created audit report at $reports"
}
