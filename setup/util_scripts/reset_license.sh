#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

# Used to reset an invalid or corrupted license key. Not normally needed unless directed to use by Sandfly
# support.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SETUP_DATA=../setup_data
VERSION=${SANDFLY_VERSION:-$(cat ../../VERSION)}
IMAGE_BASE=${SANDFLY_IMAGE_BASE:-quay.io/sandfly}

# Populate env variables.
CONFIG_JSON=$(cat $SETUP_DATA/config.node.json)
export CONFIG_JSON


docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt

docker run --name sandfly-server-mgmt \
--network sandfly-net \
-e CONFIG_JSON \
-it $IMAGE_BASE/sandfly-server-mgmt:"$VERSION" /usr/local/sandfly/utils/init_license_db.sh


