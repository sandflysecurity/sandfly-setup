#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Only execute if we have root access.
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo "${BASH_SOURCE}")."
    exit 1
fi

# Install some required utilities.
apt update
apt install \
    thin-provisioning-tools \
    lvm2 \
    ca-certificates \
    curl

# Install Docker PGP key.
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker source repository.
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install docker-ce docker-ce-cli containerd.io

service docker start
