#!/usr/bin/env bash

configure_ssh() {
    section "Configuring SSH server"

    sudo install -d -m 755 /etc/ssh/sshd_config.d

    sudo tee /etc/ssh/sshd_config.d/10-linuxbook.conf \
        >/dev/null <<'CONFIG'
# LinuxBook SSH configuration
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
X11Forwarding no
UseDNS no
CONFIG

    if sudo sshd -t; then
        success "SSH configuration passed validation"
    else
        failure "SSH configuration validation failed"
        return
    fi

    run_step "Enable and start the SSH server" \
        sudo systemctl enable --now ssh

    if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"

        ssh-keygen \
            -t ed25519 \
            -a 100 \
            -C "$USER@$(hostname)" \
            -f "$HOME/.ssh/id_ed25519" \
            -N ""

        success "Generated an Ed25519 SSH key"
    else
        echo "Existing SSH key retained."
    fi

    echo
    echo "SSH status:"
    systemctl --no-pager --full status ssh 2>/dev/null |
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
