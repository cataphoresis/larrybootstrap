#!/usr/bin/env bash

declare -a SUCCESSES=()
declare -a WARNINGS=()
declare -a FAILURES=()

if [[ "${LARRY_COLOR:-0}" == "1" ]]; then
    LARRY_GREEN=$'\033[32m'
    LARRY_YELLOW=$'\033[33m'
    LARRY_RED=$'\033[31m'
    LARRY_CYAN=$'\033[96m'
    LARRY_DARK_CYAN=$'\033[36m'
    LARRY_DARK_GRAY=$'\033[90m'
    LARRY_RESET=$'\033[0m'
else
    LARRY_GREEN=""
    LARRY_YELLOW=""
    LARRY_RED=""
    LARRY_CYAN=""
    LARRY_DARK_CYAN=""
    LARRY_DARK_GRAY=""
    LARRY_RESET=""
fi

status_ok() {
    printf '%s[ OK ]%s' "$LARRY_GREEN" "$LARRY_RESET"
}

status_warn() {
    printf '%s[WARN]%s' "$LARRY_YELLOW" "$LARRY_RESET"
}

status_fail() {
    printf '%s[FAIL]%s' "$LARRY_RED" "$LARRY_RESET"
}

status_info() {
    printf '%s[INFO]%s' "$LARRY_CYAN" "$LARRY_RESET"
}

display_path() {
    local path="$1"

    if [[ "$path" == "$PWD/"* ]]; then
        printf '%s' "${path#"$PWD/"}"
    else
        printf '%s' "$path"
    fi
}

section() {
    local title="$*"
    local border="+----------------------------------------------------------------------+"

    echo
    printf '%s%s%s\n' "$LARRY_DARK_CYAN" "$border" "$LARRY_RESET"
    printf '%s|  %-66s  |%s\n' "$LARRY_CYAN" "$title" "$LARRY_RESET"
    printf '%s%s%s\n' "$LARRY_DARK_CYAN" "$border" "$LARRY_RESET"
}
success() {
    SUCCESSES+=("$*")
    status_ok
    printf ' %s\n' "$*"
}

warning() {
    WARNINGS+=("$*")
    status_warn >&2
    printf ' %s\n' "$*" >&2
}

failure() {
    FAILURES+=("$*")
    status_fail >&2
    printf ' %s\n' "$*" >&2
}
run_step() {
    local description="$1"
    shift

    echo
    printf '%s-- %s%s\n'         "$LARRY_DARK_GRAY" "$description" "$LARRY_RESET"

    if "$@"; then
        success "$description"
        return 0
    else
        failure "$description"
        return 1
    fi
}

show_header() {
    section "LinuxBook Bootstrap v2"

    echo "Host:       $(hostname)"
    echo "User:       $USER"
    echo "Mode:       $MODE"
    echo "Started:    $(date)"
    echo "Log file:   $(display_path "$LOG_FILE")"
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

require_amd64() {
    local architecture

    architecture="$(dpkg --print-architecture)"

    if [[ "$architecture" != "amd64" ]]; then
        echo "Full workstation mode requires Debian amd64."
        echo "Detected architecture: $architecture"
        exit 1
    fi

    echo "Architecture: amd64"
}

acquire_sudo() {
    sudo -v || {
        echo "Unable to acquire sudo privileges."
        exit 1
    }
}

wait_for_package_manager() {
    section "Package manager preflight"

    local -a locks=(
        /var/lib/dpkg/lock-frontend
        /var/lib/dpkg/lock
        /var/cache/apt/archives/lock
        /var/lib/apt/lists/lock
        /var/cache/debconf/config.dat
    )

    local lock
    local holders=""
    local waited=0
    local timeout=60

    while (( waited < timeout )); do
        holders=""

        for lock in "${locks[@]}"; do
            [[ -e "$lock" ]] || continue

            if sudo fuser "$lock" >/dev/null 2>&1; then
                holders+="$(sudo fuser "$lock" 2>/dev/null) "
            fi
        done

        if [[ -z "$holders" ]]; then
            status_ok
            printf ' Package manager is available\n'
            return 0
        fi

        if (( waited == 0 )); then
            status_info
            printf ' Package manager is busy; waiting for active transaction\n'
        fi

        sleep 2
        (( waited += 2 ))
    done

    holders="$(printf '%s' "$holders" | xargs)"

    failure "Package manager remained busy after ${timeout}s"

    if [[ -n "$holders" ]]; then
        status_info
        printf ' Lock holder PID(s): %s\n' "$holders"

        ps -o pid,ppid,stat,etime,cmd -p \
            "$(printf '%s' "$holders" | tr ' ' ',' | sed 's/,$//')" \
            2>/dev/null || true
    fi

    status_info
    printf ' Lock files were not removed\n'

    return 1
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
    local -a pending=()

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

        pending+=("$package")
    done

    if [[ ${#pending[@]} -eq 0 ]]; then
        echo "No packages need installation."
        return
    fi

    echo "Installing ${#pending[@]} package(s) in one APT transaction."

    if sudo env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y "${pending[@]}"; then
        for package in "${pending[@]}"; do
            success "Installed $package"
        done
        return
    fi

    warning "Batch package installation failed; retrying individually"

    sudo dpkg --configure -a || true
    sudo apt-get -f install -y || true

    for package in "${pending[@]}"; do
        if dpkg-query -W -f='${db:Status-Abbrev}' "$package" \
            2>/dev/null | grep -q '^ii'; then
            success "Installed $package"
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

    if [[ ${#SUCCESSES[@]} -gt 0 ]]; then
        status_ok
    else
        status_info
    fi
    printf ' Successful operations: %d\n' "${#SUCCESSES[@]}"
    printf '       %s\n' "${SUCCESSES[@]}" 2>/dev/null || true

    echo

    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        status_warn
    else
        status_ok
    fi
    printf ' Warnings: %d\n' "${#WARNINGS[@]}"
    printf '       %s\n' "${WARNINGS[@]}" 2>/dev/null || true

    echo

    if [[ ${#FAILURES[@]} -gt 0 ]]; then
        status_fail
    else
        status_ok
    fi
    printf ' Failures: %d\n' "${#FAILURES[@]}"
    printf '       %s\n' "${FAILURES[@]}" 2>/dev/null || true

    echo
    status_info
    printf ' Log:     %s\n' "$(display_path "$LOG_FILE")"

    status_info
    printf ' Reports: %s\n' \
        "$(display_path "$PROJECT_DIR/reports/latest")"
}
