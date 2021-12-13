#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"
cd ..

docker version >/dev/null 2>&1 || { echo "This script must be run as root or as a user with access to the Docker daemon."; exit 1; }

cat << EOF

****************************************************************************
Renewing SSL Certs

This script will contact EFF's Let's Encrypt Bot to renew your certificates.
****************************************************************************

EOF

# Use standard docker image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="quay.io/sandfly/sandfly-server-mgmt${IMAGE_SUFFIX}:$VERSION"
fi

# Calls EFF Certbot to get a signed key for the Sandfly Server.
# publish to 80 is required by Cerbot for http connect back.
docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt 2>/dev/null

mkdir -p setup_data/letsencrypt

docker run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/usr/local/sandfly/install/setup_data \
-v $PWD/setup_data/letsencrypt:/etc/letsencrypt \
--name sandfly-server-mgmt \
--network sandfly-net \
--publish 80:80 \
-it $SANDFLY_MGMT_DOCKER_IMAGE /usr/local/sandfly/install/install_certbot.sh

if [ $? -ne 0 ]; then
  echo "Error renewing SSL certificate."
  exit 1
fi

docker rm sandfly-server-mgmt 2>/dev/null
docker run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/usr/local/sandfly/install/setup_data \
--name sandfly-server-mgmt \
--network sandfly-net \
-it $SANDFLY_MGMT_DOCKER_IMAGE /usr/local/sandfly/install/update_config_json_ssl.sh

