#!/usr/bin/env bash

configure_ssh() {
    section "Configuring SSH server"

    local config_dir="/etc/ssh/sshd_config.d"
    local config_file="$config_dir/10-linuxbook.conf"
    local temp_file
    local config_changed=false

    temp_file="$(mktemp)"

    cat > "$temp_file" <<'CONFIG'
# LinuxBook SSH configuration
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
X11Forwarding no
UseDNS no
CONFIG

    sudo install -d -m 755 "$config_dir"

    if [[ ! -f "$config_file" ]] ||
       ! sudo cmp -s "$temp_file" "$config_file"; then
        sudo install -m 644 "$temp_file" "$config_file"
        config_changed=true
        success "Updated LinuxBook SSH configuration"
    else
        echo "LinuxBook SSH configuration is already current."
    fi

    rm -f "$temp_file"

    if sudo sshd -t; then
        success "SSH configuration passed validation"
    else
        failure "SSH configuration validation failed"
        return
    fi

    run_step "Enable and start the SSH server" \
        sudo systemctl enable --now ssh

    if [[ "$config_changed" == true ]]; then
        run_step "Reload SSH server configuration" \
            sudo systemctl reload ssh
    fi

    configure_user_ed25519_key || return 1

    echo
    echo "SSH status:"
    systemctl --no-pager --full status ssh 2>&1 |
        grep -v '^Warning: some journal files were not opened due to insufficient permissions\.$' |
        head -20 || true

    echo
    echo "Connect using one of these addresses:"

    hostname -I |
        tr ' ' '\n' |
        grep -v '^$' |
        while read -r address; do
            echo "  ssh $USER@$address"
        done
}

configure_user_ed25519_key() {
    local ssh_dir="$HOME/.ssh"
    local private_key="$ssh_dir/id_ed25519"
    local public_key="$private_key.pub"
    local key_comment
    local temp_public

    key_comment="$USER@$(hostname)-larrybootstrap"

    install -d -m 0700 "$ssh_dir"

    if [[ ! -e "$private_key" ]]; then
        if ssh-keygen -q -t ed25519 -N "" -C "$key_comment" -f "$private_key"; then
            success "Generated the required user Ed25519 SSH key"
        else
            failure "Could not generate the required user Ed25519 SSH key"
            return 1
        fi
    else
        echo "Existing user Ed25519 SSH private key retained."
    fi

    if ! ssh-keygen -lf "$private_key" 2>/dev/null |
         grep -Eq '\(ED25519\)$| ED25519 '; then
        failure "$private_key is not a valid Ed25519 private key"
        return 1
    fi

    if [[ ! -f "$public_key" ]]; then
        temp_public="$(mktemp)"
        if ssh-keygen -y -f "$private_key" > "$temp_public"; then
            printf ' %s\n' "$key_comment" >> "$temp_public"
            install -m 0644 "$temp_public" "$public_key"
            success "Recreated the missing Ed25519 public key"
        else
            rm -f "$temp_public"
            failure "Could not derive the Ed25519 public key"
            return 1
        fi
        rm -f "$temp_public"
    fi

    chmod 0700 "$ssh_dir"
    chmod 0600 "$private_key"
    chmod 0644 "$public_key"

    printf 'SSH key fingerprint: '
    ssh-keygen -lf "$public_key"
}
