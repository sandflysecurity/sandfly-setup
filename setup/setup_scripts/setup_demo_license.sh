#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"
cd ..

docker version >/dev/null 2>&1 || { echo "This script must be run as root or as a user with access to the Docker daemon."; exit 1; }

# Use standard docker image unless overriden.
if [ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]; then
  VERSION=$(cat ../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="quay.io/sandfly/sandfly${IMAGE_SUFFIX}:$VERSION"
fi

# Build up a docker run command that includes any environment variables with
# SANDFLY in the name.
RUNCMD="docker run --rm -v /dev/urandom:/dev/random:ro \
  -v $PWD/setup_data:/opt/sandfly/install/setup_data \
  --network sandfly-net \
  -e CONFIG_JSON"

ENVVARS=$(env | grep SANDFLY | awk -F= '{print $1}')
if [ -n "$ENVVARS" ]; then
    for var in $ENVVARS; do
        RUNCMD+=" -e $var"
    done
fi

# And if an environment file exists, include its vars in the container
if [ -f /.digitalocean_addon_credentials ]; then
  RUNCMD+=" --env-file /.digitalocean_addon_credentials"
fi

RUNCMD+=" $SANDFLY_MGMT_DOCKER_IMAGE /opt/sandfly/utils/demolictool"
CONFIG_JSON=$(cat setup_data/config.server.json) \
  eval "$RUNCMD"

exit $?
