#!/usr/bin/env bash

configure_local_filesystems() {
    section "Local filesystem access"

    local bootcamp_device=""
    local bootcamp_uuid=""
    local current_mount=""
    local existing_mount=""
    local mount_point="/mnt/bootcamp"
    local uid_value
    local gid_value
    local fstab_entry
    local fstab_backup=""

    uid_value="$(id -u "$USER")"
    gid_value="$(id -g "$USER")"

    bootcamp_device="$(
        lsblk -rno PATH,FSTYPE,LABEL |
            awk '
                $2 ~ /^ntfs/ && toupper($3) == "BOOTCAMP" {
                    print $1
                    exit
                }
            '
    )"

    if [[ -z "$bootcamp_device" ]]; then
        status_info
        printf ' %-14s %-7s %-5s %s\n' \
            "BOOTCAMP" "NTFS" "-" "not detected; skipping"
    else
        bootcamp_uuid="$(
            lsblk -rno UUID "$bootcamp_device" 2>/dev/null |
                head -n1
        )"

        if [[ -z "$bootcamp_uuid" ]]; then
            warning "BOOTCAMP detected but UUID could not be determined"
        else
            existing_mount="$(
                awk -v uuid="UUID=$bootcamp_uuid" '
                    $1 == uuid && $1 !~ /^#/ {
                        print $2
                        exit
                    }
                ' /etc/fstab
            )"

            if [[ -n "$existing_mount" ]]; then
                if [[ "$existing_mount" == "$mount_point" ]]; then
                    :
                else
                    warning \
                        "BOOTCAMP UUID is already configured in fstab at $existing_mount; leaving it unchanged"
                fi
            elif awk -v target="$mount_point" '
                $2 == target && $1 !~ /^#/ {
                    found=1
                }
                END {
                    exit !found
                }
            ' /etc/fstab; then
                warning \
                    "Mount point $mount_point already has an fstab entry; leaving it unchanged"
            else
                sudo install -d -m 755 "$mount_point"

                fstab_entry="UUID=$bootcamp_uuid $mount_point ntfs3 rw,nofail,uid=$uid_value,gid=$gid_value,umask=022 0 0"
                fstab_backup="/etc/fstab.linuxbook-bootstrap.$(date +%Y%m%d-%H%M%S).bak"

                sudo cp -a /etc/fstab "$fstab_backup"

                if printf '%s\n' "$fstab_entry" |
                   sudo tee -a /etc/fstab >/dev/null &&
                   sudo findmnt --verify --verbose >/dev/null 2>&1; then
                    success \
                        "Configured BOOTCAMP persistent mount at $mount_point"
                    status_info
                    printf ' fstab backup: %s\n' "$fstab_backup"
                else
                    failure \
                        "New BOOTCAMP fstab configuration failed validation"

                    sudo cp -a "$fstab_backup" /etc/fstab

                    warning \
                        "Restored original /etc/fstab from $fstab_backup"
                fi
            fi

            current_mount="$(
                findmnt -rn -S "$bootcamp_device" -o TARGET 2>/dev/null |
                    head -n1
            )"

            if [[ -n "$current_mount" &&
                  "$current_mount" != "$mount_point" ]]; then
                warning \
                    "BOOTCAMP already mounted at $current_mount; persistent mount at $mount_point will take effect after reboot"
            elif [[ "$current_mount" == "$mount_point" ]]; then
                status_ok
                printf ' %-14s %-7s %-5s %s\n' \
                    "BOOTCAMP" "NTFS" "RW" "$mount_point"
            elif grep -Eq \
                "^[[:space:]]*UUID=${bootcamp_uuid}[[:space:]]+${mount_point}[[:space:]]+" \
                /etc/fstab; then
                status_info
                printf ' %-14s %-7s %-5s %s\n' \
                    "BOOTCAMP" "NTFS" "RW" \
                    "configured for next boot at $mount_point"
            fi
        fi
    fi

    local apfs_device=""

    apfs_device="$(
        lsblk -rno PATH,FSTYPE |
            awk '$2 == "apfs" { print $1; exit }'
    )"

    if [[ -z "$apfs_device" ]]; then
        status_info
        printf ' %-14s %-7s %-5s %s\n' \
            "macOS" "APFS" "-" "not detected; skipping"
    elif command -v apfs-fuse >/dev/null 2>&1; then
        status_info
        printf ' %-14s %-7s %-5s %s\n' \
            "macOS" "APFS" "RO" \
            "helper available; /mnt/macos integration reserved"
    else
        status_info
        printf ' %-14s %-7s %-5s %s\n' \
            "macOS" "APFS" "-" \
            "detected; read-only mount helper unavailable, skipping"
    fi

    if lsblk -rno FSTYPE,LABEL |
       awk '
           tolower($1) == "exfat" &&
           toupper($2) == "OSXRESERVED" {
               found=1
           }
           END {
               exit !found
           }
       '; then
        status_info
        printf ' %-14s %-7s %-5s %s\n' \
            "OSXRESERVED" "exFAT" "-" "ignored"
    fi

    if lsblk -rno FSTYPE,MOUNTPOINTS |
       awk '
           $1 == "vfat" &&
           $2 == "/boot/efi" {
               found=1
           }
           END {
               exit !found
           }
       '; then
        status_info
        printf ' %-14s %-7s %-5s %s\n' \
            "EFI" "FAT32" "-" "ignored"
    fi
}
