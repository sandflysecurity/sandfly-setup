#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.


apt-get update
apt install thin-provisioning-tools
apt install lvm2

# Allows apt to use HTTPS and other tools.
apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

# Docker PGP key add
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

apt-get update

apt-get install docker-ce

service docker start
