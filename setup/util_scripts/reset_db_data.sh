#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# This will delete all the results, errors, and audit log data from the
# Sandfly server. This is useful if the system got flooded with alarms or
# other data and you want to quickly get rid of all of it and start fresh.
# All other config data will remain untouched.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SETUP_DATA=../setup_data
VERSION=${SANDFLY_VERSION:-$(cat ../../VERSION)}
IMAGE_BASE=${SANDFLY_IMAGE_BASE:-quay.io/sandfly}

# Populate env variables if on the sandfly server.
if [ -f "$SETUP_DATA/config.server.json" ]; then
    CONFIG_JSON=$(cat $SETUP_DATA/config.server.json)
    export CONFIG_JSON
else
    echo ""
    echo "****************************** ERROR ******************************"
    echo "* The Sandfly server configuration file was not found.            *"
    echo "*                                                                 *"
    echo "* Please confirm that you are running this script on a Sandfly    *"
    echo "* server installation and not on a Sandfly node.                  *"
    echo "****************************** ERROR ******************************"
    echo ""
    exit 1
fi

# Determine if we need to use the sudo command to control Docker
SUDO=""
if [ $(id -u) -ne 0 ]; then
    docker version >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        SUDO="sudo"
    fi
fi

# Check the state of the sandfly-server container
esresult=$($SUDO docker inspect --format="{{.State.Running}}" sandfly-server 2> /dev/null)
if [ "${esresult}z" = "truez" ]; then
    echo ""
    echo "****************************** ERROR ******************************"
    echo "* The Sandfly server container is running.                        *"
    echo "*                                                                 *"
    echo "* The container must be stopped with the following command:       *"
    echo "*   docker stop sandfly-server                                    *"
    echo "*                                                                 *"
    echo "* IMPORTANT: That command will take the UI and scanning offline!  *"
    echo "*                                                                 *"
    echo "* Then run this script again. Once it has finished, restore       *"
    echo "* the Sandfly server container with the following command:        *"
    echo "*   docker start sandfly-server                                   *"
    echo "****************************** ERROR ******************************"
    echo ""
    exit 1
fi

# Check the state of the sandfly-postgres container
esresult=$($SUDO docker inspect --format="{{.State.Running}}" sandfly-postgres 2> /dev/null)
if [ "${esresult}z" != "truez" ]; then
    echo ""
    echo "****************************** ERROR ******************************"
    echo "* The Sandfly Postgres container is not running.                  *"
    echo "*                                                                 *"
    echo "* Please start the container with the following script:           *"
    echo "*   ~/sandfly-setup/start_scripts/start_postgres.sh               *"
    echo "*                                                                 *"
    echo "* Then run this script again.                                     *"
    echo "****************************** ERROR ******************************"
    echo ""
    exit 1
fi

docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt 2>/dev/null

docker run --name sandfly-server-mgmt \
--network sandfly-net \
-e CONFIG_JSON \
-it $IMAGE_BASE/sandfly${IMAGE_SUFFIX}:"$VERSION" /opt/sandfly/utils/init_data_db.sh
