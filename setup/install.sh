#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2018 Sandfly Security LTD, All Rights Reserved.

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

export SANDFLY_MGMT_DOCKER_IMAGE="sandfly/sandfly-server-mgmt:latest"

# Uncomment and change this if you wish to override what elastic DB for Sandfly so to use. The default is to use
# sandfly container version, but you can use your own cluster if you wish.
#export ELASTIC_SERVER_HOSTNAME="ip_addr_or_hostname_here"

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

./setup_scripts/setup_server.sh
./setup_scripts/setup_pgp_keys.sh
./setup_scripts/setup_ssl.sh

echo ""
echo "**********************************"
echo "*      Make Signed SSL Key?      *"
echo "**********************************"
echo ""
read -p "Generate signed SSL keys (type YES)? " RESPONSE
if [ "$RESPONSE" = "YES" ]; then
    echo "Starting key signing script"
    ./setup_scripts/setup_ssl_signed.sh
fi

echo ""
echo "**********************************"
echo "*         Setup Complete!        *"
echo "**********************************"
echo ""


