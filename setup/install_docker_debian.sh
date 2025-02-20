#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

sudo apt update
sudo apt install \
 thin-provisioning-tools \ 
 lvm2

# Allows apt to use HTTPS and other tools.
sudo apt install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg

# Docker PGP key add
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"

sudo apt update

sudo apt install docker-ce docker-ce-cli containerd.io 

sudo service docker start
