#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2022 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SETUP_DATA=../setup/setup_data
VERSION=${SANDFLY_VERSION:-$(cat ../VERSION)}
IMAGE_BASE=${SANDFLY_IMAGE_BASE:-quay.io/sandfly}

# Use valid (#m or #g) env variable, otherwise the Sandfly default.
if  [[ "${SANDFLY_LOG_MAX_SIZE}" =~ ^[1-9][0-9]*[m|g]$ ]]; then
  LOG_MAX_SIZE=${SANDFLY_LOG_MAX_SIZE}
else
  LOG_MAX_SIZE="100m"
fi

# Remove old scripts
../setup/clean_scripts.sh

if [ ! -f $SETUP_DATA/config.node.json ]; then
    echo
    echo "***************************** ERROR *******************************"
    echo
    echo "The node config data ($SETUP_DATA/config.node.json) is not present on the"
    echo "node. This file must be present for the scanning nodes to start. Please copy"
    echo "this file from the server setup_data directory and try again."
    echo
    echo "Exiting node start."
    echo "***************************** ERROR *******************************"
    echo
    exit 1
fi

# Populate env variables.
CONFIG_JSON=$(cat $SETUP_DATA/config.node.json)
export CONFIG_JSON

docker run -v /dev/urandom:/dev/random:ro \
--label sandfly-node \
-e CONFIG_JSON \
--disable-content-trust \
--restart=always \
--security-opt="no-new-privileges:true" \
--log-driver json-file \
--log-opt max-size=${LOG_MAX_SIZE} \
--log-opt max-file=5 \
-d $IMAGE_BASE/sandfly-node${IMAGE_SUFFIX}:"$VERSION" /usr/local/sandfly/start_node.sh

exit $?
