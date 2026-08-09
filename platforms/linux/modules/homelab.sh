#!/usr/bin/env bash

# LEGACY / NOT USED BY bootstrap.sh
#
# Retained for future homelab/OMV integration work.
# This script is not part of the LinuxBook workstation release path
# and should not be invoked by core, full, or audit modes.

set -e

sudo apt update

sudo apt install -y \
    tmux \
    git \
    curl \
    wget \
    unzip \
    zip \
    tree \
    htop \
    btop \
    ncdu \
    ripgrep \
    fd-find \
    bat \
    eza \
    fzf \
    jq \
    yq \
    rsync \
    screen \
    minicom \
    picocom \
    avahi-utils \
    nmap \
    iperf3 \
    mosh \
    dnsutils \
    net-tools \
    traceroute \
    whois \
    tcpdump \
    wireshark \
    ffmpeg \
    imagemagick \
    vlc
