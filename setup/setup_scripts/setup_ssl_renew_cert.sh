#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"
cd ..

# Set CONTAINERMGR variable
. ./setup_scripts/container_command.sh
if [ $? -ne 0 ]; then
    # Failed to find container runtime. The container_command script will
    # have printed an error.
    exit 1
fi

cat << EOF

****************************************************************************
Renewing SSL Certs

This script will contact Let's Encrypt to renew your certificates.
****************************************************************************

EOF

# Use standard docker image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="quay.io/sandfly/sandfly${IMAGE_SUFFIX}:$VERSION"
fi

# Calls Let's Encrypt to get a signed key for the Sandfly Server.
# publish to 80 is required by lego for http challenge.
$CONTAINERMGR network create sandfly-net 2>/dev/null
$CONTAINERMGR rm sandfly-server-mgmt 2>/dev/null

mkdir -p setup_data/letsencrypt/lego

$CONTAINERMGR run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/opt/sandfly/install/setup_data:z \
-v $PWD/setup_data/letsencrypt/lego:/etc/letsencrypt:z \
-e SSL_FQDN \
-e SSL_EMAIL \
--name sandfly-server-mgmt \
--network sandfly-net \
--publish 80:8000 \
-u root \
-it $SANDFLY_MGMT_DOCKER_IMAGE /opt/sandfly/install/install_letsencrypt.sh

if [ $? -ne 0 ]; then
  echo "Error renewing SSL certificate."
  exit 1
fi

$CONTAINERMGR rm sandfly-server-mgmt 2>/dev/null
$CONTAINERMGR run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/opt/sandfly/install/setup_data:z \
--name sandfly-server-mgmt \
--network sandfly-net \
-u root \
-it $SANDFLY_MGMT_DOCKER_IMAGE /opt/sandfly/install/update_config_json_ssl.sh

if [ $? -ne 0 ]; then
  echo "Error updating configuration with new certificate."
  exit 1
fi
