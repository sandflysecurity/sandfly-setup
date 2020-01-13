#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2020 Sandfly Security LTD, All Rights Reserved.

SETUP_DATA=../setup/setup_data
VERSION=$(cat ../VERSION)

# Populate env variables
export RABBIT_SERVER_HOSTNAME=$(cat $SETUP_DATA/rabbit.server.hostname.txt)
export RABBIT_ADMIN_PASSWORD=$(cat $SETUP_DATA/rabbit.admin.password.txt)
export RABBIT_NODE_PASSWORD=$(cat $SETUP_DATA/rabbit.node.password.txt)
export SSL_CACERT=$(cat $SETUP_DATA/cacert.b64)
export RABBIT_SSL_SERVER_CERT=$(cat $SETUP_DATA/rabbit_cert.b64)
export RABBIT_SSL_SERVER_KEY=$(cat $SETUP_DATA/rabbit_key.b64)

# Rabbit uses the hostname for the logs and node name. If you don't assign it here then Docker picks a random
# name. By setting a hostname here it makes things more legible.
# ref: https://github.com/docker-library/rabbitmq/issues/106

docker network create sandfly-net
docker rm sandfly-rabbit

docker run -v /dev/urandom:/dev/random:ro \
--hostname sandfly-rabbit -d \
-e RABBIT_NODE_PASSWORD \
-e RABBIT_ADMIN_PASSWORD \
-e SSL_CACERT \
-e RABBIT_SSL_SERVER_CERT \
-e RABBIT_SSL_SERVER_KEY \
--disable-content-trust \
--restart on-failure:5 \
--name sandfly-rabbit \
--security-opt="no-new-privileges:true" \
--publish 5673:5673 \
-t docker.io/sandfly/sandfly-rabbit:"$VERSION"
