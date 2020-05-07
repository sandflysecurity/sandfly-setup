#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2020 Sandfly Security LTD, All Rights Reserved.

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

cat << EOF

************************************************************************************************
Setting Up Server

The server install script is now starting.

************************************************************************************************

EOF

# Use standard docker image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="docker.io/sandfly/sandfly-server-mgmt:$VERSION"
fi

# Uncomment and change this if you wish to override what elastic DB for Sandfly so to use. The default is to use
# sandfly container version, but you can use your own cluster if you wish. During setup if you specified
# a custom elastic server IP address then it will be filled in above so you likely won't have to
# alter this.
#export ELASTIC_SERVER_URL="http://elasticsearch.example.com:9200"

docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt 2>/dev/null

docker run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/usr/local/sandfly/install/setup_data \
--name sandfly-server-mgmt \
--network sandfly-net \
-e ELASTIC_SERVER_URL \
-it $SANDFLY_MGMT_DOCKER_IMAGE /usr/local/sandfly/install/install_server.sh


