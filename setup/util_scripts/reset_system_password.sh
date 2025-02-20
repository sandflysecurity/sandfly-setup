#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Used to generate a new API password the scanning nodes use to post results
# data. This shouldn't be used unless requested by Sandfly.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SETUP_DATA=../setup_data
VERSION=${SANDFLY_VERSION:-$(cat ../../VERSION)}
IMAGE_BASE=${SANDFLY_IMAGE_BASE:-quay.io/sandfly}

# Populate env variables.
CONFIG_JSON=$(cat $SETUP_DATA/config.server.json)
export CONFIG_JSON

docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt 2>/dev/null

docker run --name sandfly-server-mgmt \
--network sandfly-net \
-e CONFIG_JSON \
-it $IMAGE_BASE/sandfly${IMAGE_SUFFIX}:"$VERSION" /opt/sandfly/utils/reset_system_password.sh


