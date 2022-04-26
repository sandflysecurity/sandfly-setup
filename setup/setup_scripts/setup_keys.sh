#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2022 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"
cd ..

docker version >/dev/null 2>&1 || { echo "This script must be run as root or as a user with access to the Docker daemon."; exit 1; }

cat << EOF

******************************************************************************
Setting Up Server and Node Keys
We're now setting up keys for use by the server and nodes.
******************************************************************************

EOF

# Use standard docker image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="quay.io/sandfly/sandfly-server-mgmt${IMAGE_SUFFIX}:$VERSION"
fi

# Sets up PGP keys pair for server and node.
docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt 2>/dev/null

DOCKER_INTERACTIVE="-it"
[ "$SANDFLY_AUTO" = "YES" ] && DOCKER_INTERACTIVE=""

docker run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/usr/local/sandfly/install/setup_data \
--name sandfly-server-mgmt \
--network sandfly-net \
$DOCKER_INTERACTIVE $SANDFLY_MGMT_DOCKER_IMAGE /usr/local/sandfly/install/install_keys.sh

exit $?
