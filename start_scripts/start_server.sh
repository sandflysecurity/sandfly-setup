#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2018 Sandfly Security LTD, All Rights Reserved.

SETUP_DATA=../setup/setup_data

export NODE_PGP_PUBLIC_KEY=$(cat $SETUP_DATA/node.pub.asc.b64)
export SSL_CACERT=$(cat $SETUP_DATA/cacert.b64)
export SSL_DHPARAM=$(cat $SETUP_DATA/dhparam.b64)
export SSL_NODE_CERT=$(cat $SETUP_DATA/node_cert.b64)
export SSL_NODE_KEY=$(cat $SETUP_DATA/node_key.b64)

# Uncomment and change this if you wish to override what elastic DB for Sandfly so to use. The default is to use
# sandfly container version, but you can use your own cluster if you wish.
#export ELASTIC_SERVER="ip_addr_or_hostname_here"

if [ -f $SETUP_DATA/node.sec.asc.b64 ]; then
    echo "********* WARNING ***********"
    echo ""
    echo "The node secret key $SETUP_DATA/node.sec.asc.b64 is present on the server. This key must be deleted from"
    echo "the server to fully protect the SSH keys stored in the database. It should only be on the nodes."
    echo ""
    echo ""
    echo "********* WARNING ***********"
    echo ""
    echo ""
    read -p "Are you sure you want to start the server with the node secret key present? (YES) " RESPONSE
    if [ "$RESPONSE" != "YES" ]; then
        echo "Halting server start."
        exit -1
    fi
fi


if [ -s $SETUP_DATA/server_cert_signed.b64 ]; then
    export SSL_SERVER_CERT=$(cat $SETUP_DATA/server_cert_signed.b64)
    export SSL_SERVER_KEY=$(cat $SETUP_DATA/server_key_signed.b64)
else
    export SSL_SERVER_CERT=$(cat $SETUP_DATA/server_cert.b64)
    export SSL_SERVER_KEY=$(cat $SETUP_DATA/server_key.b64)
fi

source $SETUP_DATA/secrets.env.sh

docker network create sandfly-net
docker rm sandfly-server

docker run -v /dev/urandom:/dev/random:ro \
-e NODE_PGP_PUBLIC_KEY \
-e SSL_CACERT \
-e SSL_DHPARAM \
-e SSL_SERVER_CERT \
-e SSL_SERVER_KEY \
-e SSL_NODE_CERT \
-e SSL_NODE_KEY \
-e RABBIT_ADMIN_PASSWORD \
-e RABBIT_NODE_PASSWORD \
-e ADMIN_PASSWORD \
-e API_NODE_PASSWORD \
-e API_SERVER_HOSTNAME \
-e RABBIT_SERVER_HOSTNAME \
-e FERNET_PASSWORD \
-e LOGIN_SCREEN_PASSWORD \
--disable-content-trust \
--restart on-failure:5 \
--security-opt="no-new-privileges:true" \
--network sandfly-net \
--name sandfly-server \
--publish 443:8443 \
-d sandfly/sandfly-server:latest /usr/local/sandfly/start_api.sh
