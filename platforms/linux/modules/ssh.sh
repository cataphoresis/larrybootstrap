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

    if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
        echo "Existing user Ed25519 SSH key retained."
    else
        warning "No user Ed25519 SSH key found; no key was generated automatically"
    fi

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
