#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

SETUP_DATA=../setup/setup_data
VERSION=$(cat ../VERSION)

# Populate env variables.
RABBIT_SERVER_HOSTNAME=$(cat $SETUP_DATA/rabbit.server.hostname.txt)
RABBIT_NODE_PASSWORD=$(cat $SETUP_DATA/rabbit.node.password.txt)
API_SERVER_HOSTNAME=$(cat $SETUP_DATA/api.server.hostname.txt)
API_NODE_PASSWORD=$(cat $SETUP_DATA/api.node.password.txt)
SSL_CACERT=$(cat $SETUP_DATA/cacert.b64)
SSL_NODE_CERT=$(cat $SETUP_DATA/node_cert.b64)
SSL_NODE_KEY=$(cat $SETUP_DATA/node_key.b64)
NODE_PGP_SECRET_KEY=$(cat $SETUP_DATA/node.sec.asc.b64)

export RABBIT_SERVER_HOSTNAME
export RABBIT_NODE_PASSWORD
export API_SERVER_HOSTNAME
export API_NODE_PASSWORD
export SSL_CACERT
export SSL_NODE_CERT
export SSL_NODE_KEY
export NODE_PGP_SECRET_KEY


# Node thread values. Please do not change this unless instructed for performance reasons.
export CONCURRENCY=500

# ONLY ignore certs if you are not able to sign certs for the API server.
export IGNORE_CERTS=true
#export IGNORE_CERTS=false


docker run -v /dev/urandom:/dev/random:ro \
-e RABBIT_NODE_PASSWORD \
-e SSL_CACERT \
-e SSL_NODE_CERT \
-e SSL_NODE_KEY \
-e RABBIT_SERVER_HOSTNAME \
-e API_SERVER_HOSTNAME \
-e API_NODE_PASSWORD \
-e NODE_PGP_SECRET_KEY \
-e IGNORE_CERTS \
-e CONCURRENCY \
--disable-content-trust \
--restart on-failure:5 \
--security-opt="no-new-privileges:true" \
-d quay.io/sandfly/sandfly-node:"$VERSION" /usr/local/sandfly/start_node.sh
