#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

SETUP_DATA=../setup/setup_data
VERSION=$(cat ../VERSION)

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
    read -p "Are you sure you want to start the server with the node secret key present? Type YES if you're sure. (NO): " RESPONSE
    if [ "$RESPONSE" != "YES" ]; then
        echo "Halting server start."
        exit 1
    fi
fi

# Populate env variables.
RABBIT_SERVER_HOSTNAME=$(cat $SETUP_DATA/rabbit.server.hostname.txt)
RABBIT_ADMIN_PASSWORD=$(cat $SETUP_DATA/rabbit.admin.password.txt)
RABBIT_NODE_PASSWORD=$(cat $SETUP_DATA/rabbit.node.password.txt)
API_SERVER_HOSTNAME=$(cat $SETUP_DATA/api.server.hostname.txt)
API_NODE_PASSWORD=$(cat $SETUP_DATA/api.node.password.txt)
FERNET_PASSWORD=$(cat $SETUP_DATA/fernet.password.b64)
NODE_PGP_PUBLIC_KEY=$(cat $SETUP_DATA/node.pub.asc.b64)
SSL_CACERT=$(cat $SETUP_DATA/cacert.b64)
SSL_DHPARAM=$(cat $SETUP_DATA/dhparam.b64)
SSL_NODE_CERT=$(cat $SETUP_DATA/node_cert.b64)
SSL_NODE_KEY=$(cat $SETUP_DATA/node_key.b64)

export RABBIT_SERVER_HOSTNAME
export RABBIT_ADMIN_PASSWORD
export RABBIT_NODE_PASSWORD
export API_SERVER_HOSTNAME
export API_NODE_PASSWORD
export FERNET_PASSWORD
export NODE_PGP_PUBLIC_KEY
export SSL_CACERT
export SSL_DHPARAM
export SSL_NODE_CERT
export SSL_NODE_KEY


# Use signed cert if present, otherwise use unsigned.
if [ -s $SETUP_DATA/server_cert_signed.b64 ]; then
    echo "Using signed certificate for server."
    SSL_SERVER_CERT=$(cat $SETUP_DATA/server_cert_signed.b64)
    SSL_SERVER_KEY=$(cat $SETUP_DATA/server_key_signed.b64)
else
    echo "Using UNSIGNED certificate for server. Be sure you start the node with the unsigned start script!"
    SSL_SERVER_CERT=$(cat $SETUP_DATA/server_cert.b64)
    SSL_SERVER_KEY=$(cat $SETUP_DATA/server_key.b64)
fi
export SSL_SERVER_CERT
export SSL_SERVER_KEY

if [ -f $SETUP_DATA/elastic.server.hostname.txt ]; then
  echo "Found old elasticsearch hostname format. Upgrading to new URL format."
  ELASTIC_SERVER_HOSTNAME_OLD=$(cat $SETUP_DATA/elastic.server.hostname.txt)
  echo "http://$ELASTIC_SERVER_HOSTNAME_OLD:9200" > $SETUP_DATA/elastic.server.url.txt
  rm $SETUP_DATA/elastic.server.hostname.txt
fi

# Internal DB elasticsearch URL. You can modify this file if you are using an elasticsearch cluster that is not
# located on the same host as the Sandfly server.
ELASTIC_SERVER_URL=$(cat $SETUP_DATA/elastic.server.url.txt)
export ELASTIC_SERVER_URL

# Setup elasticsearch ca certificate if they are using one.
if [ -f $SETUP_DATA/elastic.server.url.cacert.b64 ]; then
  echo "Found certificate for Elasticsearch server."
  SSL_ELASTIC_SERVER_CERT=$(cat $SETUP_DATA/elastic.server.url.cacert.b64)
else
  echo "No certificate found for Elasticsearch server. Ignoring."
fi
export SSL_ELASTIC_SERVER_CERT

# Setup elasticsearch results replication server url if needed.
if [ -f $SETUP_DATA/elastic.server.url.replication.txt ]; then
  ELASTIC_SERVER_URL_REPLICATION=$(cat $SETUP_DATA/elastic.server.url.replication.txt)
fi
export ELASTIC_SERVER_URL_REPLICATION

# Setup elasticsearch replication ca certificate if they are using one.
if [ -f $SETUP_DATA/elastic.server.url.replication.cacert.b64 ]; then
  echo "Found certificate for Elasticsearch replication server."
  SSL_ELASTIC_SERVER_REPLICATION_CERT=$(cat $SETUP_DATA/elastic.server.url.replication.cacert.b64)
else
  echo "No certificate found for Elasticsearch replication server. Ignoring."
fi
export SSL_ELASTIC_SERVER_REPLICATION_CERT


if [ -f $SETUP_DATA/login.screen.password.txt ]; then
    LOGIN_SCREEN_PASSWORD=$(cat $SETUP_DATA/login.screen.password.txt)
fi
export LOGIN_SCREEN_PASSWORD

docker network create sandfly-net 2>/dev/null
docker rm sandfly-server 2>/dev/null

docker run -v /dev/urandom:/dev/random:ro \
-e NODE_PGP_PUBLIC_KEY \
-e SSL_CACERT \
-e SSL_DHPARAM \
-e SSL_SERVER_CERT \
-e SSL_SERVER_KEY \
-e SSL_NODE_CERT \
-e SSL_NODE_KEY \
-e SSL_ELASTIC_SERVER_CERT \
-e SSL_ELASTIC_SERVER_REPLICATION_CERT \
-e RABBIT_SERVER_HOSTNAME \
-e RABBIT_ADMIN_PASSWORD \
-e RABBIT_NODE_PASSWORD \
-e API_SERVER_HOSTNAME \
-e API_NODE_PASSWORD \
-e ELASTIC_SERVER_URL \
-e ELASTIC_SERVER_URL_REPLICATION \
-e FERNET_PASSWORD \
-e LOGIN_SCREEN_PASSWORD \
--disable-content-trust \
--restart on-failure:5 \
--security-opt="no-new-privileges:true" \
--network sandfly-net \
--name sandfly-server \
--publish 443:8443 \
--publish 80:8000 \
-d docker.io/sandfly/sandfly-server:"$VERSION" /usr/local/sandfly/start_api.sh
