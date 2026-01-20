#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

#############################################################################
# Update the running server container's TLS certificate and key.            #
#############################################################################

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SETUP_DATA=../setup_data

# Set CONTAINERMGR variable
. ./container_command.sh
if [ $? -ne 0 ]; then
    # Failed to find container runtime. The container_command script will
    # have printed an error.
    exit 1
fi

if [ -z "$($CONTAINERMGR ps -q -f name=sandfly-server)" ]; then
    echo "The sandfly-server container is not running."
    exit 1
fi

# Populate env variables.
CONFIG_JSON=$(cat $SETUP_DATA/config.server.json)
export CONFIG_JSON

# Server SSL certificate overrides from files
CONFIG_SSL_CERT=""
CONFIG_SSL_KEY=""

if [ -f $SETUP_DATA/server_ssl_cert/cert.pem ]; then
    CONFIG_SSL_CERT=$(cat $SETUP_DATA/server_ssl_cert/cert.pem)
fi

if [ -f $SETUP_DATA/server_ssl_cert/privatekey.pem ]; then
    CONFIG_SSL_KEY=$(cat $SETUP_DATA/server_ssl_cert/privatekey.pem)
fi

export CONFIG_SSL_CERT CONFIG_SSL_KEY

$CONTAINERMGR exec \
-e CONFIG_JSON \
-e CONFIG_SSL_CERT -e CONFIG_SSL_KEY \
sandfly-server /opt/sandfly/reload_server_cert.sh

exit $?
