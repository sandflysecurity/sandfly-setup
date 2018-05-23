#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2018 Sandfly Security LTD, All Rights Reserved.

SETUP_DATA=../setup/setup_data

source $SETUP_DATA/secrets.node.env.sh

export SSL_CACERT=$(cat $SETUP_DATA/cacert.b64)
export SSL_NODE_CERT=$(cat $SETUP_DATA/node_cert.b64)
export SSL_NODE_KEY=$(cat $SETUP_DATA/node_key.b64)
export NODE_PGP_SECRET_KEY=$(cat $SETUP_DATA/node.sec.asc.b64)

# ONLY ignore certs if you are not able to sign certs for the API server.
#export IGNORE_CERTS=true
export IGNORE_CERTS=false

docker run -v /dev/urandom:/dev/random:ro \
-e LOG_LEVEL=debug \
-e RABBIT_NODE_PASSWORD \
-e SSL_CACERT \
-e SSL_NODE_CERT \
-e SSL_NODE_KEY \
-e RABBIT_SERVER_HOSTNAME \
-e API_SERVER_HOSTNAME \
-e API_NODE_PASSWORD \
-e NODE_PGP_SECRET_KEY \
-e IGNORE_CERTS \
--disable-content-trust \
--restart on-failure:5 \
--security-opt="no-new-privileges:true" \
-d sandfly/sandfly-node:latest /usr/local/sandfly/start_node.sh

