#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2018 Sandfly Security LTD, All Rights Reserved.

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# Generates initial SSL keys for the Sandfly Server.
docker network create sandfly-net
docker rm sandfly-server-mgmt


docker run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/usr/local/sandfly/install/setup_data \
--name sandfly-server-mgmt \
--network sandfly-net \
-it sandfly/sandfly-server-mgmt:latest /usr/local/sandfly/install/install_ssl.sh



