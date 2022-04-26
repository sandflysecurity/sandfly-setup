#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2022 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"
cd ..

docker version >/dev/null 2>&1 || { echo "This script must be run as root or as a user with access to the Docker daemon."; exit 1; }

# Use standard docker image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="quay.io/sandfly/sandfly-server-mgmt${IMAGE_SUFFIX}:$VERSION"
fi

CONFIG_JSON=$(cat setup_data/config.server.json) \
  docker run --rm -v /dev/urandom:/dev/random:ro \
  -v $PWD/setup_data:/usr/local/sandfly/install/setup_data \
  --network sandfly-net \
  -e CONFIG_JSON \
  $SANDFLY_MGMT_DOCKER_IMAGE /usr/local/sandfly/utils/demolictool

exit $?
