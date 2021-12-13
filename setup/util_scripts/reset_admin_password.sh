#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Resets the admin account to a new random password. Used to recover a lost or forgotten admin password.
SETUP_DATA=../setup_data
VERSION=${SANDFLY_VERSION:-$(cat ../../VERSION)}
IMAGE_BASE=${SANDFLY_IMAGE_BASE:-quay.io/sandfly}

# Populate env variables.
CONFIG_JSON=$(cat $SETUP_DATA/config.server.json)
export CONFIG_JSON


docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt

docker run --name sandfly-server-mgmt \
--network sandfly-net \
-e CONFIG_JSON \
-it $IMAGE_BASE/sandfly-server-mgmt${IMAGE_SUFFIX}:"$VERSION" /usr/local/sandfly/utils/reset_admin_password.sh

