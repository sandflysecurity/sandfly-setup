#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2019 Sandfly Security LTD, All Rights Reserved.

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
