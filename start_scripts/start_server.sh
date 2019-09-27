#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2019 Sandfly Security LTD, All Rights Reserved.

SETUP_DATA=../setup/setup_data

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

# This converts legacy environment variable scripts to the new file format. This will be removed in later versions.
if [ -f $SETUP_DATA/secrets.env.sh ]; then
    echo "Old format password data was found. Converting it to new format now."
    # This inits the env variables we are about to use below from the legacy format.
    source $SETUP_DATA/secrets.env.sh
    # Decode these values. The new format uses plain values and encodes when needed internally.
    echo "Converting Rabbit server hostname."
    echo $RABBIT_SERVER_HOSTNAME | base64 -d > $SETUP_DATA/rabbit.server.hostname.txt
    echo "Converting Rabbit admin password."
    echo $RABBIT_ADMIN_PASSWORD | base64 -d > $SETUP_DATA/rabbit.admin.password.txt
    echo "Converting Rabbit node password."
    echo $RABBIT_NODE_PASSWORD | base64 -d> $SETUP_DATA/rabbit.node.password.txt
    echo "Converting API server hostname."
    echo $API_SERVER_HOSTNAME | base64 -d > $SETUP_DATA/api.server.hostname.txt
    echo "Converting API node password."
    echo $API_NODE_PASSWORD | base64 -d > $SETUP_DATA/api.node.password.txt
    echo "Converting admin password (left over from install)."
    echo $ADMIN_PASSWORD | base64 -d > $SETUP_DATA/admin.password.txt

    echo "Setting elasticsearch server name."
    echo "elasticsearch" > $SETUP_DATA/elastic.server.hostname.txt

    echo "Saving Fernet password to new file."
    echo $FERNET_PASSWORD > $SETUP_DATA/fernet.password.b64

    if [ -z $LOGIN_SCREEN_PASSWORD ]; then
        echo "No pre-login screen password found to convert. Skipping."
    else
        echo "Converting pre-login screen password."
        echo $LOGIN_SCREEN_PASSWORD > $SETUP_DATA/login.screen.password.txt
    fi

    echo "Making backup of old secrets.env.sh file"
    cp $SETUP_DATA/secrets.env.sh $SETUP_DATA/secrets.env.sh.bak
    echo "Removing old secrets.env.sh file"
    rm $SETUP_DATA/secrets.env.sh
fi

# Populate env variables.
export RABBIT_SERVER_HOSTNAME=$(cat $SETUP_DATA/rabbit.server.hostname.txt)
export RABBIT_ADMIN_PASSWORD=$(cat $SETUP_DATA/rabbit.admin.password.txt)
export RABBIT_NODE_PASSWORD=$(cat $SETUP_DATA/rabbit.node.password.txt)
export API_SERVER_HOSTNAME=$(cat $SETUP_DATA/api.server.hostname.txt)
export API_NODE_PASSWORD=$(cat $SETUP_DATA/api.node.password.txt)
export FERNET_PASSWORD=$(cat $SETUP_DATA/fernet.password.b64)
export NODE_PGP_PUBLIC_KEY=$(cat $SETUP_DATA/node.pub.asc.b64)
export SSL_CACERT=$(cat $SETUP_DATA/cacert.b64)
export SSL_DHPARAM=$(cat $SETUP_DATA/dhparam.b64)
export SSL_NODE_CERT=$(cat $SETUP_DATA/node_cert.b64)
export SSL_NODE_KEY=$(cat $SETUP_DATA/node_key.b64)

# Use signed cert if present, otherwise use unsigned.
if [ -s $SETUP_DATA/server_cert_signed.b64 ]; then
    echo "Using signed certificate for server."
    export SSL_SERVER_CERT=$(cat $SETUP_DATA/server_cert_signed.b64)
    export SSL_SERVER_KEY=$(cat $SETUP_DATA/server_key_signed.b64)
else
    echo "Using UNSIGNED certificate for server. Be sure you start the node with the unsigned start script!"
    export SSL_SERVER_CERT=$(cat $SETUP_DATA/server_cert.b64)
    export SSL_SERVER_KEY=$(cat $SETUP_DATA/server_key.b64)
fi

# Setup elasticsearch server name to custom here if needed.
export ELASTIC_SERVER_HOSTNAME=$(cat $SETUP_DATA/elastic.server.hostname.txt)
# Uncomment and change this if you wish to override what elastic DB for Sandfly so to use. The default is to use
# sandfly container version, but you can use your own cluster if you wish.
#export ELASTIC_SERVER_HOSTNAME="ip_addr_or_hostname_here"

if [ -f $SETUP_DATA/login.screen.password.txt ]; then
    export LOGIN_SCREEN_PASSWORD=$(cat $SETUP_DATA/login.screen.password.txt)
fi


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
-e RABBIT_SERVER_HOSTNAME \
-e RABBIT_ADMIN_PASSWORD \
-e RABBIT_NODE_PASSWORD \
-e API_SERVER_HOSTNAME \
-e API_NODE_PASSWORD \
-e ELASTIC_SERVER_HOSTNAME \
-e FERNET_PASSWORD \
-e LOGIN_SCREEN_PASSWORD \
--disable-content-trust \
--restart on-failure:5 \
--security-opt="no-new-privileges:true" \
--network sandfly-net \
--name sandfly-server \
--publish 443:8443 \
--publish 80:8000 \
-d docker.io/sandfly/sandfly-server:latest /usr/local/sandfly/start_api.sh
