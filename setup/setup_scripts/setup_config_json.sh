#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2022 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"
cd ..

docker version >/dev/null 2>&1 || { echo "This script must be run as root or as a user with access to the Docker daemon."; exit 1; }

cat << EOF

******************************************************************************
Creating Server, Node and Rabbit Configs
Creating final config JSON with all generated install values.
******************************************************************************

EOF

# Use standard docker image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="quay.io/sandfly/sandfly-server${IMAGE_SUFFIX}:$VERSION"
fi

docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt 2>/dev/null

DOCKER_INTERACTIVE="-it"
[ "$SANDFLY_AUTO" = "YES" ] && DOCKER_INTERACTIVE=""

docker run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/opt/sandfly/install/setup_data \
--name sandfly-server-mgmt \
--network sandfly-net \
-e ELASTIC_SERVER_URL \
-e SANDFLY_SETUP_AUTO_HOSTNAME \
$DOCKER_INTERACTIVE $SANDFLY_MGMT_DOCKER_IMAGE /opt/sandfly/install/install_config_json.sh

exit $?
