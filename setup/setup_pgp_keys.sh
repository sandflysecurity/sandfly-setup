#!/usr/bin/env sh
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2018 Sandfly Security LTD, All Rights Reserved.

# Sets up PGP keys pair for server and node.
docker network create sandfly-net
docker rm sandfly-server-mgmt


docker run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/usr/local/sandfly/install/setup_data \
--name sandfly-server-mgmt \
--network sandfly-net \
-it sandfly/sandfly-server-mgmt:latest /usr/local/sandfly/install/create_node_pgp_keys.sh

