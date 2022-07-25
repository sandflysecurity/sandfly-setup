#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2022 Sandfly Security LTD, All Rights Reserved.

# This script will install the Sandfly server. By default, it will run
# through an interactive setup process that is appropriate for users wishing
# to control the location of Rabbit, etc.
#
# The script is also capable of performing a non-interactive automated all-
# in-one single-system setup. To perform the automated setup, set the
# environment variable SANDFLY_SETUP_AUTO_HOSTNAME to the hostname of the
# Sandfly server.
#
# By default, the script will use the version from the ../VERSION file
# and will pull images from the quay.io/sandfly Docker repository. To
# override these defaults, set SANDFLY_SETUP_VERSION to the version tag
# on the sandfly-server-mgmt Docker image and/or set
# SANDFLY_SETUP_DOCKER_BASE to the prefix of the Docker image tag to use.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"
SETUP_DATA_DIR=./setup_data

VERSION=${SANDFLY_SETUP_VERSION:-$(cat ../VERSION)}
DOCKER_BASE=${SANDFLY_SETUP_DOCKER_BASE:-quay.io/sandfly}
export SANDFLY_MGMT_DOCKER_IMAGE="$DOCKER_BASE/sandfly-server${IMAGE_SUFFIX}:$VERSION"

# Sandfly already installed?
if [ -f $SETUP_DATA_DIR/config.server.json ]; then
    echo ""
    echo "********************************** ERROR **********************************"
    echo "*                                                                         *"
    echo "* Sandfly is already installed (there is a config.server.json file in     *"
    echo "* the setup_data directory).                                              *"
    echo "*                                                                         *"
    echo "* If you are upgrading to a new version of Sandfly, please use upgrade.sh *"
    echo "*                                                                         *"
    echo "* If you wish to completely delete your old Sandfly configuration and     *"
    echo "* database, please use delete_sandfly_installation.sh in the util_scripts *"
    echo "* directory.                                                              *"
    echo "*                                                                         *"
    echo "********************************** ERROR **********************************"
    echo ""
    exit 1
fi

# Is this an automated install?
[ -n "$SANDFLY_SETUP_AUTO_HOSTNAME" ] && export SANDFLY_AUTO=YES

clear
cat << EOF
Installing Sandfly server version $VERSION.

Copyright (c)2016-$(date +%Y) Sandfly Security Ltd.

Welcome to the Sandfly $VERSION server setup.

EOF

# See if we can run Docker
which docker >/dev/null 2>&1 || { echo "Unable to locate docker binary; please install Docker."; exit 1; }
docker version >/dev/null 2>&1 || { echo "This script must be run as root or as a user with access to the Docker daemon."; exit 1; }

# Sandfly Postgres Docker volume already exists?
docker inspect sandfly-pg14-db-vol >/dev/null 2>&1
if [[ $? -eq 0 ]]
then
    echo ""
    echo "********************************** ERROR **********************************"
    echo "*                                                                         *"
    echo "* Sandfly is already installed (the database Docker volume,               *"
    echo "* sandfly-pg14-db-vol, exists).                                           *"
    echo "*                                                                         *"
    echo "* If you are upgrading to a new version of Sandfly, please use upgrade.sh *"
    echo "*                                                                         *"
    echo "* If you wish to completely delete your old Sandfly configuration and     *"
    echo "* database, please use delete_sandfly_installation.sh in the util_scripts *"
    echo "* directory.                                                              *"
    echo "*                                                                         *"
    echo "********************************** ERROR **********************************"
    echo ""
    exit 1
fi

[ "$SANDFLY_AUTO" = "YES" ] && cat << EOF
This will be a fully-automated setup.

Hostname: $SANDFLY_SETUP_AUTO_HOSTNAME
Sandfly Management Image: $SANDFLY_MGMT_DOCKER_IMAGE

EOF

docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt 2>/dev/null

# The first time we start Postgres, we need to assign a superuser password.
POSTGRES_ADMIN_PASSWORD=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c40)
echo "$POSTGRES_ADMIN_PASSWORD" > $SETUP_DATA_DIR/postgres.admin.password.txt
echo "Starting Postgres database."
../start_scripts/start_postgres.sh
sleep 5

./setup_scripts/setup_server.sh
if [[ $? -ne 0 ]]
then
  echo "Server setup did not run. Aborting install."
  exit 1
fi

./setup_scripts/setup_keys.sh
if [[ $? -ne 0 ]]
then
  echo "Server and node key setup did not run. Aborting install."
  exit 1
fi

# Need to provide the API server hostname, which was written to a file in
# setup_server.sh, to generate the SSL cert.
SSL_SERVER_HOSTNAME=$(cat ./setup_data/api.server.hostname.txt)
export SSL_SERVER_HOSTNAME

./setup_scripts/setup_ssl.sh
if [[ $? -ne 0 ]]
then
  echo "SSL setup did not run. Aborting install."
  exit 1
fi

if [ -z "$SANDFLY_AUTO" ]; then
  cat << EOF

******************************************************************************
Make Signed SSL Key?

If the Sandfly server is able to be seen on the Internet, we can generate a
signed key using EFF's Let's Encrypt Bot. Answer below if you'd like to do
this.
******************************************************************************

EOF
  read -p "Generate signed SSL keys (type YES)? " RESPONSE
  if [[ "$RESPONSE" = "YES" ]]
  then
      echo "Starting key signing script"
      ./setup_scripts/setup_ssl_signed.sh
  fi
fi # if auto

./setup_scripts/setup_config_json.sh
if [[ $? -ne 0 ]]
then
  echo "Server, node and rabbit config JSON could not be generated. Aborting install."
  exit 1
fi


cat << EOF

******************************************************************************
Setup Complete!

Your setup is complete. Please see below for the path to the admin password to
login.

You will need to go to $(realpath $PWD/../start_scripts) and run the following to start the
server:

./start_sandfly.sh

Your randomly generated password for the admin account is located under:

$PWD/setup_data/admin.password.txt
******************************************************************************

EOF
