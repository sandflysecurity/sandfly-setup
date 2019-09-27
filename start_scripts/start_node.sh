#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2019 Sandfly Security LTD, All Rights Reserved.

SETUP_DATA=../setup/setup_data

# This converts legacy environment variable scripts to the new file format. This will be removed in later versions.
if [ -f $SETUP_DATA/secrets.node.env.sh ]; then
    echo "Old format password data was found. Converting it to new format now."
    source $SETUP_DATA/secrets.node.env.sh
    # Decode these values. The new format uses plain values and encodes when needed internally.
    echo "Converting Rabbit server hostname."
    echo $RABBIT_SERVER_HOSTNAME | base64 -d > $SETUP_DATA/rabbit.server.hostname.txt
    echo "Converting Rabbit node password."
    echo $RABBIT_NODE_PASSWORD | base64 -d> $SETUP_DATA/rabbit.node.password.txt
    echo "Converting API server hostname."
    echo $API_SERVER_HOSTNAME | base64 -d > $SETUP_DATA/api.server.hostname.txt
    echo "Converting API node password."
    echo $API_NODE_PASSWORD | base64 -d > $SETUP_DATA/api.node.password.txt

    echo "Making backup of old secrets.node.env.sh file"
    cp $SETUP_DATA/secrets.node.env.sh $SETUP_DATA/secrets.node.env.sh.bak
    echo "Removing old secrets.node.env.sh file"
    rm $SETUP_DATA/secrets.node.env.sh
fi

# Populate env variables.
export RABBIT_SERVER_HOSTNAME=$(cat $SETUP_DATA/rabbit.server.hostname.txt)
export RABBIT_NODE_PASSWORD=$(cat $SETUP_DATA/rabbit.node.password.txt)
export API_SERVER_HOSTNAME=$(cat $SETUP_DATA/api.server.hostname.txt)
export API_NODE_PASSWORD=$(cat $SETUP_DATA/api.node.password.txt)
export SSL_CACERT=$(cat $SETUP_DATA/cacert.b64)
export SSL_NODE_CERT=$(cat $SETUP_DATA/node_cert.b64)
export SSL_NODE_KEY=$(cat $SETUP_DATA/node_key.b64)
export NODE_PGP_SECRET_KEY=$(cat $SETUP_DATA/node.sec.asc.b64)

# Node thread values. Please do not change this unless instructed for performance reasons.
export CONCURRENCY=500

# ONLY ignore certs if you are not able to sign certs for the API server.
#export IGNORE_CERTS=true
export IGNORE_CERTS=false


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
-d docker.io/sandfly/sandfly-node:latest /usr/local/sandfly/start_node.sh
