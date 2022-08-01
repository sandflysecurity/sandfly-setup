#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2022 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"
cd ..

if [ !$(which docker >/dev/null 2>&1 ) ]; then
    which podman >/dev/null 2>&1 || { echo "Unable to locate docker or podman binary; please install Docker or Podman."; exit 1; }
    CONTAINER_BINARY=podman
else
    CONTAINER_BINARY=docker
fi
cat << EOF

****************************************************************************
Renewing SSL Certs

This script will contact EFF's Let's Encrypt Bot to renew your certificates.
****************************************************************************

EOF

# Use standard $CONTAINER_BINARY image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="quay.io/sandfly/sandfly-server${IMAGE_SUFFIX}:$VERSION"
fi

# Calls EFF Certbot to get a signed key for the Sandfly Server.
# publish to 80 is required by Cerbot for http connect back.
$CONTAINER_BINARY network create sandfly-net 2>/dev/null
$CONTAINER_BINARY rm sandfly-server-mgmt 2>/dev/null

mkdir -p setup_data/letsencrypt

$CONTAINER_BINARY run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/opt/sandfly/install/setup_data \
-v $PWD/setup_data/letsencrypt:/etc/letsencrypt \
--name sandfly-server-mgmt \
--network sandfly-net \
--publish 80:8000 \
-it $SANDFLY_MGMT_DOCKER_IMAGE /opt/sandfly/install/install_certbot.sh

if [ $? -ne 0 ]; then
  echo "Error renewing SSL certificate."
  exit 1
fi

$CONTAINER_BINARY rm sandfly-server-mgmt 2>/dev/null
$CONTAINER_BINARY run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/opt/sandfly/install/setup_data \
--name sandfly-server-mgmt \
--network sandfly-net \
-it $SANDFLY_MGMT_DOCKER_IMAGE /opt/sandfly/install/update_config_json_ssl.sh

if [ $? -ne 0 ]; then
  echo "Error updating configuration with new certificate."
  exit 1
fi
