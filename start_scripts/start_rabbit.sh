#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2022 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SETUP_DATA=../setup/setup_data
VERSION=${SANDFLY_VERSION:-$(cat ../VERSION)}
IMAGE_BASE=${SANDFLY_IMAGE_BASE:-quay.io/sandfly}

# Populate env variables.
CONFIG_JSON=$(cat $SETUP_DATA/config.rabbit.json)
export CONFIG_JSON

docker network create sandfly-net 2>/dev/null
docker rm sandfly-rabbit 2>/dev/null

# The upstream RabbitMQ container definition requires a volume. We will manage
# it here so we don't get a new randomly-named volume filling up the hard
# drive at every startup. We always re-initialize the RabbitMQ configuration
# and security when the container starts, so this is just a temporary volume.
docker volume rm sandfly-rabbitmq-tmp-vol 2>/dev/null

# Rabbit uses the hostname for the logs and node name. If you don't assign it
# here then Docker picks a random name. By setting a hostname here it makes
# things more legible.
# ref: https://github.com/docker-library/rabbitmq/issues/106

docker run -v /dev/urandom:/dev/random:ro \
    --mount type=volume,source=sandfly-rabbitmq-tmp-vol,target=/var/lib/rabbitmq \
    --hostname sandfly-rabbit -d \
    -e CONFIG_JSON \
    --disable-content-trust \
    --restart=always \
    --name sandfly-rabbit \
    --security-opt="no-new-privileges:true" \
    --network sandfly-net \
    --publish 5673:5673 \
    -t $IMAGE_BASE/sandfly-rabbit${IMAGE_SUFFIX}:"$VERSION"
