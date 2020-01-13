#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2020 Sandfly Security LTD, All Rights Reserved.

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

VERSION=$(cat ../VERSION)
export SANDFLY_MGMT_DOCKER_IMAGE="docker.io/sandfly/sandfly-server-mgmt:$VERSION"

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
if [[ $? -eq 1 ]]
then
  echo "Server setup did not run. Aborting install."
  exit 1
fi

./setup_scripts/setup_pgp_keys.sh
if [[ $? -eq 1 ]]
then
  echo "PGP key setup did not run. Aborting install."
  exit 1
fi

./setup_scripts/setup_ssl.sh
if [[ $? -eq 1 ]]
then
  echo "SSL setup did not run. Aborting install."
  exit 1
fi

echo ""
echo "**********************************"
echo "*      Make Signed SSL Key?      *"
echo "**********************************"
echo ""
read -p "Generate signed SSL keys (type YES)? " RESPONSE
if [[ "$RESPONSE" = "YES" ]]; then
    echo "Starting key signing script"
    ./setup_scripts/setup_ssl_signed.sh
fi

echo ""
echo "**********************************"
echo "*         Setup Complete!        *"
echo "**********************************"
echo ""
echo ""
echo "Your randomly generated password for the admin account is is located under:"
echo ""
echo "$PWD/setup_data/admin.password.txt"
echo ""

