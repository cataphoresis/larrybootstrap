#!/usr/bin/env bash

declare -a SUCCESSES=()
declare -a WARNINGS=()
declare -a FAILURES=()

section() {
    echo
    echo "============================================================"
    echo " $*"
    echo "============================================================"
}

success() {
    SUCCESSES+=("$*")
    printf '[ OK ] %s\n' "$*"
}

warning() {
    WARNINGS+=("$*")
    printf '[WARN] %s\n' "$*" >&2
}

failure() {
    FAILURES+=("$*")
    printf '[FAIL] %s\n' "$*" >&2
}

info() {
    printf '[INFO] %s\n' "$*"
}

run_step() {
    local description="$1"
    shift

    echo
    echo "-- $description"

    if "$@"; then
        success "$description"
        return 0
    else
        failure "$description"
        return 1
    fi
}

show_header() {
    local os_name="Linux"
    [[ -r /etc/os-release ]] && os_name="$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-Linux}")"

    section "Linux Bootstrap"
    printf 'Mode:       %s\n' "$MODE"
    printf 'User:       %s\n' "$(id -un)"
    printf 'Computer:   %s\n' "$(hostname)"
    printf 'System:     %s\n' "$os_name"
    printf 'Shell:      Bash %s\n' "$BASH_VERSION"
    printf 'Started:    %s\n' "$(date)"
    printf 'Log file:   %s\n' "$LOG_FILE"
}

require_debian() {
    if [[ ! -r /etc/os-release ]]; then
        echo "Unable to identify this operating system."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${ID:-}" != "debian" ]]; then
        echo "This bootstrap is intended for Debian."
        echo "Detected: ${PRETTY_NAME:-unknown}"
        exit 1
    fi

    echo "Detected: ${PRETTY_NAME:-Debian}"
}

require_normal_user() {
    if [[ $EUID -eq 0 ]]; then
        echo "Run this script as your normal account, not as root."
        exit 1
    fi
}

acquire_sudo() {
    sudo -v || {
        echo "Unable to acquire sudo privileges."
        exit 1
    }
}

apt_repair() {
    section "Repairing interrupted package operations"

    sudo dpkg --configure -a || warning "dpkg configuration still reported an error"
    sudo apt-get -f install -y || warning "APT dependency repair reported an error"
}

configure_multiarch() {
    section "Configuring 32-bit compatibility"

    if ! dpkg --print-foreign-architectures | grep -qx i386; then
        sudo dpkg --add-architecture i386
        success "Enabled i386 multiarch"
    else
        echo "i386 multiarch is already enabled."
    fi
}

apt_update_upgrade() {
    section "Updating Debian"

    run_step "Refresh APT package lists" \
        sudo apt-get update

    run_step "Install available Debian updates" \
        sudo env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
}

install_apt_packages() {
    local group_name="$1"
    shift
    local package

    section "$group_name"

    for package in "$@"; do
        if dpkg-query -W -f='${db:Status-Abbrev}' "$package" \
            2>/dev/null | grep -q '^ii'; then
            echo "Already installed: $package"
            continue
        fi

        if ! apt-cache show "$package" >/dev/null 2>&1; then
            warning "Not available from configured repositories: $package"
            continue
        fi

        if sudo env DEBIAN_FRONTEND=noninteractive \
            apt-get install -y "$package"; then
            success "Installed $package"
        else
            failure "Could not install $package"
            sudo dpkg --configure -a || true
            sudo apt-get -f install -y || true
        fi
    done
}

show_summary() {
    section "Bootstrap summary"

    echo "Successful operations: ${#SUCCESSES[@]}"
    printf '  + %s\n' "${SUCCESSES[@]}" 2>/dev/null || true

    echo
    echo "Warnings: ${#WARNINGS[@]}"
    printf '  ! %s\n' "${WARNINGS[@]}" 2>/dev/null || true

    echo
    echo "Failures: ${#FAILURES[@]}"
    printf '  - %s\n' "${FAILURES[@]}" 2>/dev/null || true

    echo
    echo "Log:"
    echo "  $LOG_FILE"

    echo
    echo "Audit reports:"
    echo "  $PROJECT_DIR/reports/latest"
}
