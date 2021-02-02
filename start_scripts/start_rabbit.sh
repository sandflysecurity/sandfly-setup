#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

SETUP_DATA=../setup/setup_data
VERSION=$(cat ../VERSION)

# Populate env variables
RABBIT_SERVER_HOSTNAME=$(cat $SETUP_DATA/rabbit.server.hostname.txt)
RABBIT_ADMIN_PASSWORD=$(cat $SETUP_DATA/rabbit.admin.password.txt)
RABBIT_NODE_PASSWORD=$(cat $SETUP_DATA/rabbit.node.password.txt)
SSL_CACERT=$(cat $SETUP_DATA/cacert.b64)
RABBIT_SSL_SERVER_CERT=$(cat $SETUP_DATA/rabbit_cert.b64)
RABBIT_SSL_SERVER_KEY=$(cat $SETUP_DATA/rabbit_key.b64)

export RABBIT_SERVER_HOSTNAME
export RABBIT_ADMIN_PASSWORD
export RABBIT_NODE_PASSWORD
export SSL_CACERT
export RABBIT_SSL_SERVER_CERT
export RABBIT_SSL_SERVER_KEY


# Rabbit uses the hostname for the logs and node name. If you don't assign it here then Docker picks a random
# name. By setting a hostname here it makes things more legible.
# ref: https://github.com/docker-library/rabbitmq/issues/106

docker network create sandfly-net 2>/dev/null
docker rm sandfly-rabbit 2>/dev/null

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
-t quay.io/sandfly/sandfly-rabbit:"$VERSION"
