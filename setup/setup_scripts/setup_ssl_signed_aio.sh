#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# This script installs a Let's Encrypt SSL certificate on a sandfly system
# that has previously been auto-configured, such as cloud marketplace
# single-server images.
#
# If you have performed a traditional installation of Sandfly, please follow
# the instructions in the documentation to enable or renew SSL, not this
# script.

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

EXTERNALIP=$(dig @ns1.google.com -4 TXT o-o.myaddr.l.google.com +short | tr -d \")
if [ $? -ne 0 ]; then
    echo "*** ERROR: Unable to get external IP"
    exit 1
fi

RUNNING=""
cid=$($CONTAINERMGR  ps -f name=sandfly-server -q)
if [ -n "$cid" ]; then
  RUNNING=true
fi

cat << EOF

****************************************************************************
Requesting Certificate from Let's Encrypt

We are now going to try to contact Let's Encrypt to sign our certificate.
The Sandfly server must be accessible from the internet on TCP port 80 for
this procedure to work.

This script will temporarily stop the Sandfly server.
****************************************************************************

ACTION REQUIRED: you must add a public DNS entry for this host that resolves
  to the outside internet IP address of this server ($EXTERNALIP). Port 80
  must be open from the internet for Let's Encrypt to complete its validation.

EOF

echo "What is the public DNS entry for this server (e.g. \"sandfly.example.com\")?"
echo -n "==> "
read SSL_FQDN

if [ -z "$SSL_FQDN" ]; then
  echo "*** ERROR: No fully-qualified domain name was provided."
  exit 1
fi

export SSL_FQDN

# Need to stop sandfly-server so certbot can listen on port 80
if [ -n "$RUNNING" ]; then
  echo "Stopping sandfly-server..."
  $CONTAINERMGR stop sandfly-server
fi

# Use standard docker image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="quay.io/sandfly/sandfly${IMAGE_SUFFIX}:$VERSION"
fi

$CONTAINERMGR network create sandfly-net 2>/dev/null
$CONTAINERMGR rm sandfly-server-mgmt 2>/dev/null

mkdir -p setup_data/letsencrypt/lego

$CONTAINERMGR run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/opt/sandfly/install/setup_data:z \
-v $PWD/setup_data/letsencrypt/lego:/etc/letsencrypt:z \
-e SSL_FQDN \
--name sandfly-server-mgmt \
--network sandfly-net \
--publish 80:8000 \
-u root \
-it $SANDFLY_MGMT_DOCKER_IMAGE /opt/sandfly/install/install_letsencrypt.sh

if [ $? -ne 0 ]; then
  echo
  echo "*** ERROR Could not get certificate. Please correct"
  echo "          the problem and run this script again."
  echo

  if [ -n "$RUNNING" ]; then
    echo "Re-starting Sandfly Server."
    cd ../start_scripts
    ./start_server.sh
  fi

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
  echo
  echo "*** ERROR Could not update the configuration JSON. Please correct"
  echo "          the problem and run this script again."
  echo

  if [ -n "$RUNNING" ]; then
    echo "Re-starting Sandfly Server."
    cd ../start_scripts
    ./start_server.sh
  fi

  exit 1
fi

if [ -n "$RUNNING" ]; then
  echo "Re-starting Sandfly Server."
  cd ../start_scripts
  ./start_server.sh
fi

echo "Done!"
