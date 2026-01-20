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
Creating Server and Node configs.
Creating final config JSON with all generated install values.
******************************************************************************

EOF

# Use standard docker image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  VERSION=$(cat ../VERSION)
  SANDFLY_MGMT_DOCKER_IMAGE="quay.io/sandfly/sandfly${IMAGE_SUFFIX}:$VERSION"
fi

$CONTAINERMGR  network create sandfly-net 2>/dev/null
$CONTAINERMGR  rm sandfly-server-mgmt 2>/dev/null

DOCKER_INTERACTIVE="-it"
[ "$SANDFLY_AUTO" = "YES" ] && DOCKER_INTERACTIVE=""

$CONTAINERMGR run -v /dev/urandom:/dev/random:ro \
-v $PWD/setup_data:/opt/sandfly/install/setup_data:z \
--name sandfly-server-mgmt \
--network sandfly-net \
-e SANDFLY_SETUP_AUTO_HOSTNAME \
-u root \
$DOCKER_INTERACTIVE $SANDFLY_MGMT_DOCKER_IMAGE /opt/sandfly/install/install_config_json.sh

exit $?
