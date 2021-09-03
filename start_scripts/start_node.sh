#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SETUP_DATA=../setup/setup_data
VERSION=${SANDFLY_VERSION:-$(cat ../VERSION)}
IMAGE_BASE=${SANDFLY_IMAGE_BASE:-quay.io/sandfly}

if [ ! -f $SETUP_DATA/config.node.json ]; then
    echo "********* ERROR ***********"
    echo ""
    echo "The node config data ($SETUP_DATA/config.node.json) is not present on the"
    echo "node. This file must be present for the scanning nodes to start. Please copy"
    echo "this file from the server setup_data directory and try again."
    echo ""
    echo "Exiting node start."
    exit 1
fi

# Populate env variables.
CONFIG_JSON=$(cat $SETUP_DATA/config.node.json)
export CONFIG_JSON

docker run -v /dev/urandom:/dev/random:ro \
-e CONFIG_JSON \
--disable-content-trust \
--restart on-failure:5 \
--security-opt="no-new-privileges:true" \
-d $IMAGE_BASE/sandfly-node:"$VERSION" /usr/local/sandfly/start_node.sh
