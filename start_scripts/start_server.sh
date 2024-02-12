#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2022 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SETUP_DATA=../setup/setup_data
VERSION=${SANDFLY_VERSION:-$(cat ../VERSION)}
IMAGE_BASE=${SANDFLY_IMAGE_BASE:-quay.io/sandfly}

# Use valid (#m or #g) env variable, otherwise the Sandfly default.
if  [[ "${SANDFLY_LOG_MAX_SIZE}" =~ ^[1-9][0-9]*[m|g]$ ]]; then
  LOG_MAX_SIZE=${SANDFLY_LOG_MAX_SIZE}
else
  LOG_MAX_SIZE="100m"
fi

# Remove old scripts
../setup/clean_scripts.sh

if [ -e $SETUP_DATA/allinone ]; then
    IGNORE_NODE_DATA_WARNING=YES
fi

if [ -f "/snap/bin/docker" ]; then
    echo ""
    echo "****************************** ERROR ******************************"
    echo "*                                                                 *"
    echo "* A version of Docker appears to be installed via Snap.           *"
    echo "*                                                                 *"
    echo "* Sandfly is only compatible with the apt version of Docker.      *"
    echo "* Having both versions installed will conflict with Sandfly.      *"
    echo "* Please remove the snap version before starting the server.      *"
    echo "*                                                                 *"
    echo "****************************** ERROR ******************************"
    echo ""
    exit 1
fi

if [ ! -f ../setup/setup_data/config.server.json ]; then
    echo ""
    echo "********************************** ERROR **********************************"
    echo "*                                                                         *"
    echo "* Sandfly does not appear to be configured. Please use install.sh to      *"
    echo "* perform a new installation of Sandfly on this host.                     *"
    echo "*                                                                         *"
    echo "********************************** ERROR **********************************"
    echo ""
    exit 1
fi

if [ -f $SETUP_DATA/config.node.json -a "$IGNORE_NODE_DATA_WARNING" != "YES" ]; then
    echo ""
    echo "********************************* WARNING *********************************"
    echo "*                                                                         *"
    echo "* The node config data file at:                                           *"
    printf "*     %-67s *\n" "$SETUP_DATA/config.node.json"
    echo "* is present on the server.                                               *"
    echo "*                                                                         *"
    echo "* This file must be deleted from the server to fully protect the SSH keys *"
    echo "* stored in the database. It should only be on the nodes.                 *"
    echo "*                                                                         *"
    echo "********************************* WARNING *********************************"
    echo ""
    echo "Are you sure you want to start the server with the node config data present?"
    read -p "Type YES if you're sure. [NO]: " RESPONSE
    if [ "$RESPONSE" != "YES" ]; then
        echo "Halting server start."
        exit 1
    fi
fi

# jq might not be available on the outer Docker host, so we'll do a simple grep
# to make sure the config version is correct for this server version.

# Config version 2 means we need to warn about clearing results.
grep -q \"config_version\":\ 2, $SETUP_DATA/config.server.json > /dev/null
if [ $? -eq 0 ]; then
    clear
    echo ""
    echo "************************ A T T E N T I O N ************************"
    echo "*                                                                 *"
    echo "* Upgrading to this version of Sandfly will clear all results     *"
    echo "* from the database.                                              *"
    echo "*                                                                 *"
    echo "* If you do NOT wish to upgrade, press Ctrl-C now to cancel.      *"
    echo "* Otherwise, press enter to continue.                             *"
    echo "*                                                                 *"
    echo "*******************************************************************"
    echo ""
    echo "Press enter to continue"
    read foo_enter
    
    # Update config file so we don't warn on future startups.
    sed -i 's/"config_version": 2/"config_version": 3/' $SETUP_DATA/config.server.json
fi

# As a safety net, we'll check for the correct config version.
grep -q \"config_version\":\ 3, $SETUP_DATA/config.server.json > /dev/null
if [ $? -ne 0 ]; then
    echo ""
    echo "****************************** ERROR ******************************"
    echo "*                                                                 *"
    echo "* Unexpected configuration version. Please contact Sandfly        *"
    echo "* Support for assistance repairing your installation.             *"
    echo "*                                                                 *"
    echo "*******************************************************************"
    echo ""
    exit 1
fi

# Old versions of Sandfly may have left behind a temporary volume for the
# old rabbit container. Clean it up if present.
docker volume rm sandfly-rabbitmq-tmp-vol 2>/dev/null

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

docker network create sandfly-net 2>/dev/null
docker rm sandfly-server 2>/dev/null

docker run -v /dev/urandom:/dev/random:ro \
-e CONFIG_JSON \
-e CONFIG_SSL_CERT -e CONFIG_SSL_KEY \
--disable-content-trust \
--restart=always \
--security-opt="no-new-privileges:true" \
--network sandfly-net \
--name sandfly-server \
--label sandfly-server \
--user sandfly:sandfly \
--publish 443:8443 \
--publish 80:8000 \
--log-driver json-file \
--log-opt max-size=${LOG_MAX_SIZE} \
--log-opt max-file=5 \
-d $IMAGE_BASE/sandfly${IMAGE_SUFFIX}:"$VERSION" /opt/sandfly/start_api.sh

exit $?
