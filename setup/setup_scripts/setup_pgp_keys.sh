#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2020 Sandfly Security LTD, All Rights Reserved.

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

echo ""
echo "**********************************"
echo "*      Generating PGP Keys       *"
echo "**********************************"
echo ""

# Use standard docker image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="docker.io/sandfly/sandfly-server-mgmt:$VERSION"
fi

# Sets up PGP keys pair for server and node.
docker network create sandfly-net
docker rm sandfly-server-mgmt

docker run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/usr/local/sandfly/install/setup_data \
--name sandfly-server-mgmt \
--network sandfly-net \
-it $SANDFLY_MGMT_DOCKER_IMAGE /usr/local/sandfly/install/create_node_pgp_keys.sh

