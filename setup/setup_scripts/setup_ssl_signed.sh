#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2024 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"
cd ..

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

cat << EOF

************************************************************************************************
Generating Signed Certificates

We are now going to try to contact EFF's Let's Encrypt Bot to sign our certificates. The server
must be visible online to TCP port 80 for this procedure to work.

If the system is behind a firewall or private network, you will need to use self-signed
certificates or an internal CA to sign your certificates for the server.

************************************************************************************************

EOF

# Use standard docker image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="quay.io/sandfly/sandfly${IMAGE_SUFFIX}:$VERSION"
fi

# Calls EFF Certbot to get a signed key for the Sandfly Server.
# publish to 80 is required by Cerbot for http connect back.
docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt 2>/dev/null

mkdir -p setup_data/letsencrypt

docker run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/opt/sandfly/install/setup_data \
-v $PWD/setup_data/letsencrypt:/etc/letsencrypt \
-e SSL_FQDN \
-e SSL_EMAIL \
--name sandfly-server-mgmt \
--network sandfly-net \
--publish 80:8000 \
-it $SANDFLY_MGMT_DOCKER_IMAGE /opt/sandfly/install/install_certbot.sh

exit $?
