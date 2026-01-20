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

******************************************************************************
Generating Signed Certificates

We are now going to try to contact Let's Encrypt to sign our certificates. The
server must be visible online to TCP port 80 for this procedure to work.

If the system is behind a firewall or private network, you will need to use
self-signed certificates or an internal CA to sign your certificates for the
server.
******************************************************************************

EOF

# Use standard docker image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="quay.io/sandfly/sandfly${IMAGE_SUFFIX}:$VERSION"
fi

# Calls Let's Encrypt to get a signed certificate for the Sandfly Server.
# publish to 80 is required by lego for http challenge.
$CONTAINERMGR network create sandfly-net 2>/dev/null
$CONTAINERMGR rm sandfly-server-mgmt 2>/dev/null

mkdir -p setup_data/letsencrypt/lego

$CONTAINERMGR  run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/opt/sandfly/install/setup_data:z \
-v $PWD/setup_data/letsencrypt/lego:/etc/letsencrypt:z \
-e SSL_FQDN \
-e SSL_EMAIL \
--name sandfly-server-mgmt \
--network sandfly-net \
--publish 80:8000 \
-u root \
-it $SANDFLY_MGMT_DOCKER_IMAGE /opt/sandfly/install/install_letsencrypt.sh

exit $?
