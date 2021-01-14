#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

# This will delete all the results, errors, and audit log data from the Sandfly server. This is useful if
# the system got flooded with alarms or other data and you want to quickly get rid of all of it and start fresh.
# All other config data will remain untouched.

SETUP_DATA=../setup_data

# Use standard docker image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="docker.io/sandfly/sandfly-server-mgmt:$VERSION"
fi

# Setup elasticsearch server name to custom here if needed.
ELASTIC_SERVER_URL=$(cat $SETUP_DATA/elastic.server.url.txt)
# Uncomment and change this if you wish to override what elastic DB for Sandfly so to use. The default is to use
# sandfly container version, but you can use your own cluster if you wish.
#export ELASTIC_SERVER_URL="http://elasticsearch.example.com:9200"
export ELASTIC_SERVER_URL

docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt

docker run --name sandfly-server-mgmt \
--network sandfly-net \
-e ELASTIC_SERVER_URL \
-it $SANDFLY_MGMT_DOCKER_IMAGE /usr/local/sandfly/utils/init_data_db.sh



