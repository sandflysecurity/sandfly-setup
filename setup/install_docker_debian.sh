#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Only execute if we have root access.
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo "${BASH_SOURCE}")."
    exit 1
fi

apt update
apt install \
    thin-provisioning-tools \
    lvm2

# Allows apt to use HTTPS and other tools.
apt install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg

# Docker PGP key add
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/debian \
    $(lsb_release -cs) \
    stable"

apt update

apt install docker-ce docker-ce-cli containerd.io 

service docker start
