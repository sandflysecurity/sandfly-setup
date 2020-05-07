#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2020 Sandfly Security LTD, All Rights Reserved.

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
  VERSION=$(cat ../../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="docker.io/sandfly/sandfly-server-mgmt:$VERSION"
fi

# Calls EFF Certbot to get a signed key for the Sandfly Server.
# publish to 80 is required by Cerbot for http connect back.
docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt 2>/dev/null

docker run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/usr/local/sandfly/install/setup_data \
--name sandfly-server-mgmt \
--network sandfly-net \
--publish 80:80 \
-it $SANDFLY_MGMT_DOCKER_IMAGE /usr/local/sandfly/install/install_certbot.sh



