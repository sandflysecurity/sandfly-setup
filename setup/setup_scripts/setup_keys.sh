#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2022 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"
cd ..

if [ !$(which docker >/dev/null 2>&1 ) ]; then
    which podman >/dev/null 2>&1 || { echo "Unable to locate docker or podman binary; please install Docker or Podman."; exit 1; }
    CONTAINER_BINARY=podman
else
    CONTAINER_BINARY=docker
fi

cat << EOF

******************************************************************************
Setting Up Server and Node Keys
We're now setting up keys for use by the server and nodes.
******************************************************************************

EOF

# Use standard $CONTAINER_BINARY image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="quay.io/sandfly/sandfly-server${IMAGE_SUFFIX}:$VERSION"
fi

# Sets up PGP keys pair for server and node.
$CONTAINER_BINARY network create sandfly-net 2>/dev/null
$CONTAINER_BINARY rm sandfly-server-mgmt 2>/dev/null

DOCKER_INTERACTIVE="-it"
[ "$SANDFLY_AUTO" = "YES" ] && DOCKER_INTERACTIVE=""

$CONTAINER_BINARY run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/opt/sandfly/install/setup_data \
--name sandfly-server-mgmt \
--network sandfly-net \
$DOCKER_INTERACTIVE $SANDFLY_MGMT_DOCKER_IMAGE /opt/sandfly/install/install_keys.sh

exit $?
