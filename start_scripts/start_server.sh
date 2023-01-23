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
grep -q \"config_version\":\ 2, $SETUP_DATA/config.server.json
if [ $? != 0 ]; then
    echo ""
    echo "****************************** ERROR ******************************"
    echo "*                                                                 *"
    echo "* The version of the server configuration file does not match     *"
    echo "* this version of the Sandfly server. Please perform the upgrade  *"
    echo "* procedure before starting Sandfly.                              *"
    echo "*                                                                 *"
    echo "* The setup/upgrade.sh script will upgrade Sandfly to the current *"
    echo "* version.                                                        *"
    echo "*                                                                 *"
    echo "*******************************************************************"
    echo ""
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
--user sandflyserver:sandfly \
--publish 443:8443 \
--publish 80:8000 \
--log-driver json-file \
--log-opt max-size=${LOG_MAX_SIZE} \
--log-opt max-file=5 \
-d $IMAGE_BASE/sandfly-server${IMAGE_SUFFIX}:"$VERSION" /opt/sandfly/start_api.sh

exit $?
