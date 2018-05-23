#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2018 Sandfly Security LTD, All Rights Reserved.

# Sets up new install of Sandfly server.

WORKING_DIR=$PWD

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# Uncomment and change this if you wish to override what elastic DB for Sandfly so to use. The default is to use
# sandfly container version, but you can use your own cluster if you wish.
#export ELASTIC_SERVER="ip_addr_or_hostname_here"

docker network create sandfly-net
docker rm sandfly-server-mgmt

echo "Starting Elasticsearch Server. Please wait a bit."
../start_scripts/start_elastic.sh
echo "Waiting 30 seconds for Elasticsearch to start and settle down."
sleep 10
echo "Waiting 20 seconds."
sleep 10
echo "Waiting 10 seconds."
sleep 10

docker run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/usr/local/sandfly/install/setup_data \
--name sandfly-server-mgmt \
--network sandfly-net \
-e ELASTIC_SERVER \
-it sandfly/sandfly-server-mgmt:latest /usr/local/sandfly/install/install_server.sh





