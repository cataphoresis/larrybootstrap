#!/usr/bin/env bash

configure_smb_shares() {
    section "Authenticated SMB shares"
    local share_path="${LARRY_SHARE_PATH:-/mnt/larryshare}"
    if [[ ! "$USER" =~ ^[a-z_][a-z0-9_-]*\$?$ ]]; then
        failure "Unsupported Samba account name"
        return 1
    fi
    if [[ "$share_path" != /* || "$share_path" == *$'\n'* ]] ||
       ! mountpoint -q "$share_path"; then
        failure "LarryShare must be a mounted volume: $share_path"
        return 1
    fi
    local temporary backup
    temporary="$(mktemp -d)" || return 1
    backup="/etc/samba/larry-backup-$(date +%Y%m%d-%H%M%S)"
    if [[ ! -f /etc/samba/larrybootstrap.conf ]] &&
       testparm -s 2>/dev/null | grep -Eiq '^\[(OS|LarryShare)\]$'; then
        failure "An unmanaged OS or LarryShare share already exists; leaving it unchanged"
        rm -rf "$temporary"
        return 1
    fi
    cat > "$temporary/shares.conf" <<EOF
# LarryBootstrap managed shares. Filesystem permissions remain effective.
[OS]
    path = /
    browseable = yes
    read only = yes
    guest ok = no
    valid users = $USER
    follow symlinks = no
    wide links = no

[LarryShare]
    path = $share_path
    browseable = yes
    read only = no
    guest ok = no
    valid users = $USER
    follow symlinks = no
    wide links = no
    create mask = 0660
    directory mask = 0770
EOF
    # Re-enter global context so include never lands inside an existing share.
    awk '
        $0 == "# BEGIN LarryBootstrap shares" { skip=1; next }
        $0 == "# END LarryBootstrap shares" { skip=0; next }
        !skip { print }
    ' /etc/samba/smb.conf > "$temporary/smb.conf"
    printf '# BEGIN LarryBootstrap shares\n[global]\ninclude = %s/shares.conf\n# END LarryBootstrap shares\n' \
        "$temporary" >> "$temporary/smb.conf"
    if ! testparm -s "$temporary/smb.conf" >/dev/null; then
        failure "Samba configuration validation failed"
        rm -rf "$temporary"
        return 1
    fi
    sed "s|include = $temporary/shares.conf|include = /etc/samba/larrybootstrap.conf|" \
        "$temporary/smb.conf" > "$temporary/final.conf"
    if ! sudo install -d -m 0700 "$backup" ||
       ! sudo cp -p /etc/samba/smb.conf "$backup/smb.conf"; then
        rm -rf "$temporary"
        return 1
    fi
    if [[ -f /etc/samba/larrybootstrap.conf ]]; then
        sudo cp -p /etc/samba/larrybootstrap.conf "$backup/larrybootstrap.conf" || return 1
    fi
    if ! sudo install -m 0644 "$temporary/shares.conf" /etc/samba/larrybootstrap.conf ||
       ! sudo install -m 0644 "$temporary/final.conf" /etc/samba/smb.conf; then
        failure "Could not install Samba configuration; backup: $backup"
        rm -rf "$temporary"
        return 1
    fi
    rm -rf "$temporary"
    if ! sudo pdbedit -L -u "$USER" 2>/dev/null | grep -q "^$USER:"; then
        if [[ -t 0 ]]; then
            echo "Set the SMB password for $USER (entered locally; not saved in bootstrap files)."
            sudo smbpasswd -a "$USER" || return 1
        else
            warning "SMB account setup pending: run sudo smbpasswd -a $USER in a terminal"
        fi
    fi
    if sudo systemctl enable --now smbd && sudo systemctl reload smbd; then
        success "SMB OS share is read-only; LarryShare is read/write; guest access disabled"
        echo "Connect to smb://$(hostname)/OS or smb://$(hostname)/LarryShare as $USER"
    else
        failure "Samba service setup failed; configuration backup: $backup"
        return 1
    fi
}
