#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2022 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SETUP_DATA=../setup/setup_data
VERSION=${SANDFLY_VERSION:-$(cat ../VERSION)}
IMAGE_BASE=${SANDFLY_IMAGE_BASE:-quay.io/sandfly}

if [ !$(which docker >/dev/null 2>&1 ) ]; then
    which podman >/dev/null 2>&1 || { echo "Unable to locate docker or podman binary; please install Docker or Podman."; exit 1; }
    CONTAINER_BINARY=podman
else
    CONTAINER_BINARY=docker
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

# Check if we have network connectivity to the server RabbitMQ and API service.

# First, use jq inside the container (we can't assume jq is available on host)
# to get the hostname of the server.
API_HOST=$($CONTAINER_BINARY run -e CONFIG_JSON --rm \
    -e CONFIG_JSON \
    $IMAGE_BASE/sandfly-node${IMAGE_SUFFIX}:"$VERSION" \
    /bin/bash -c 'jq -r .node.api.hostname <<< $CONFIG_JSON')
RABBIT_HOST=$($CONTAINER_BINARY run -e CONFIG_JSON --rm \
    -e CONFIG_JSON \
    $IMAGE_BASE/sandfly-node${IMAGE_SUFFIX}:"$VERSION" \
    /bin/bash -c 'jq -r .node.rabbit.hostname <<< $CONFIG_JSON')

# Then test connectivity
echo "Checking connectivity to Sandfly server..."
API_OPEN=$(timeout 5 bash -c "</dev/tcp/\"$API_HOST\"/443" 2>/dev/null && echo "1" || echo "0")
AMQP_OPEN=$(timeout 5 bash -c "</dev/tcp/\"$RABBIT_HOST\"/5673" 2>/dev/null && echo "1" || echo "0")

if [[ $API_OPEN -eq 0 ]]; then
    echo
    echo "***************************** ERROR *******************************"
    echo "Port 443 is not open to the Sandfly Server at:"
    echo "$API_HOST"
    echo
    echo "Check that:"
    echo " - The sandfly-server container is running on the server."
    echo " - All firewalls are allowing the connection to port 443."
    echo "***************************** ERROR *******************************"
    echo
fi
if [[ $AMQP_OPEN -eq 0 ]]; then
    echo
    echo "***************************** ERROR *******************************"
    echo "Port 5673 is not open to the Sandfly RabbitMQ service at:"
    echo "$RABBIT_HOST"
    echo
    echo "Check that:"
    echo " - The sandfly-rabbit container is running on the server."
    echo " - All firewalls are allowing the connection to port 5673."
    echo "***************************** ERROR *******************************"
    echo
fi
if [[ $API_OPEN -eq 0 ]] || [[ $AMQP_OPEN -eq 0 ]]; then
    exit 1
fi

$CONTAINER_BINARY run -v /dev/urandom:/dev/random:ro \
-e CONFIG_JSON \
--disable-content-trust \
--restart=always \
--security-opt="no-new-privileges$( if [ $CONTAINER_BINARY == "podman" ]; then echo ""; else echo ":true"; fi)" \
-d $IMAGE_BASE/sandfly-node${IMAGE_SUFFIX}:"$VERSION" /usr/local/sandfly/start_node.sh
