#!/usr/bin/env bash

install_pia() {
    section "Private Internet Access"
    if [[ -x /opt/piavpn/bin/pia-client ]]; then
        success "PIA is already installed"
        return
    fi
    local installer arch digest
    arch="$(dpkg --print-architecture)"
    case "$arch" in
        amd64)
            installer=pia-linux-3.7.2-08420.run
            digest=08a88af04462a9e078aeef52b26bcdb56f0a9b087a0fb7606f98b7eb79bb3dd9 ;;
        arm64)
            installer=pia-linux-arm64-3.7.2-08420.run
            digest=3956d1ed9b6977f24ca960e78dd60572edd435f71b2a554e5c5d00f94603eeb9 ;;
        *) failure "No reviewed PIA installer for $arch"; return 1 ;;
    esac
    mkdir -p "$DOWNLOAD_DIR"
    if ! download_verified_file \
        "https://installers.privateinternetaccess.com/download/$installer" \
        "$DOWNLOAD_DIR/$installer" "$digest"; then
        failure "PIA download or checksum validation failed"
        return 1
    fi
    # PIA's self-extracting installer requests sudo itself; run as desktop user.
    if sh "$DOWNLOAD_DIR/$installer" && [[ -x /opt/piavpn/bin/pia-client ]]; then
        success "Installed PIA; open the app to sign in"
    else
        failure "PIA installation did not complete"
        return 1
    fi
}

install_chatgpt() {
    section "Official ChatGPT desktop"
    if dpkg-query -W -f='${db:Status-Abbrev}' chatgpt 2>/dev/null | grep -q '^ii'; then
        success "ChatGPT is already installed"
        return
    fi
    local arch temporary
    arch="$(dpkg --print-architecture)"
    case "$arch" in amd64|arm64) ;; *) failure "Unsupported ChatGPT architecture: $arch"; return 1 ;; esac
    temporary="$(mktemp -d)" || return 1
    if ! curl --fail --location --retry 3 --connect-timeout 15 --max-time 600 \
        "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_$arch.deb" \
        -o "$temporary/chatgpt.deb" ||
       [[ "$(dpkg-deb -f "$temporary/chatgpt.deb" Package 2>/dev/null)" != chatgpt ]] ||
       [[ "$(dpkg-deb -f "$temporary/chatgpt.deb" Architecture 2>/dev/null)" != "$arch" ]]; then
        rm -rf "$temporary"
        failure "Official ChatGPT package download or metadata validation failed"
        return 1
    fi
    if sudo apt-get install -y "$temporary/chatgpt.deb"; then
        success "Installed official ChatGPT desktop; open ChatGPT to sign in"
    else
        rm -rf "$temporary"
        failure "ChatGPT installation failed"
        return 1
    fi
    rm -rf "$temporary"
}

install_precompiled_apfs_fuse() {
    section "Precompiled APFS read-only tools"
    if [[ "$(dpkg --print-architecture)" != amd64 ]]; then
        warning "The bundled APFS build is Debian 13 amd64 only"
        return
    fi
    local assets
    assets="$(cd "$(dirname "${BASH_SOURCE[0]}")/../assets/apfs-fuse" && pwd)" || return 1
    if ! (cd "$assets" && sha256sum --check --status SHA256SUMS); then
        failure "Bundled APFS checksum validation failed"
        return 1
    fi
    if ! file "$assets/apfs-fuse" | grep -q 'ELF 64-bit.*x86-64'; then
        failure "Unexpected bundled APFS architecture"
        return 1
    fi
    # Copy to an executable local filesystem before checking on exFAT checkouts.
    local temporary tool
    temporary="$(mktemp -d)" || return 1
    for tool in apfs-fuse apfsutil; do
        install -m 0755 "$assets/$tool" "$temporary/$tool" || return 1
        if ldd "$temporary/$tool" 2>&1 | grep -q 'not found'; then
            rm -rf "$temporary"
            failure "APFS runtime libraries are missing; rerun the core APT install"
            return 1
        fi
    done
    if sudo install -m 0755 "$temporary/apfs-fuse" "$temporary/apfsutil" /usr/local/bin/; then
        success "Installed precompiled read-only APFS tools"
    else
        rm -rf "$temporary"
        failure "APFS tool installation failed"
        return 1
    fi
    rm -rf "$temporary"
}
