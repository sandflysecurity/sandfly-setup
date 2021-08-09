#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

# This script will install the Sandfly server. By default, it will run
# through an interactive setup process that is appropriate for users wishing
# to control the location of Elasticsearch, Rabbit, etc.
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

VERSION=${SANDFLY_SETUP_VERSION:-$(cat ../VERSION)}
DOCKER_BASE=${SANDFLY_SETUP_DOCKER_BASE:-quay.io/sandfly}
export SANDFLY_MGMT_DOCKER_IMAGE="$DOCKER_BASE/sandfly-server-mgmt:$VERSION"

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

[ "$SANDFLY_AUTO" = "YES" ] && cat << EOF
This will be a fully-automated setup.

Hostname: $SANDFLY_SETUP_AUTO_HOSTNAME
Sandfly Management Image: $SANDFLY_MGMT_DOCKER_IMAGE

EOF

if [ -z "$SANDFLY_AUTO" ]; then
  cat << EOF

******************************************************************************
Elasticsearch Database Setup

If you want to use an external Elasticsearch cluster, please fill in the field
below with the URL. Otherwise, just hit enter and we'll use the default URL.

The default URL is internally routed only with the Sandfly server and is not
reachable over the network.

External Elasticsearch clusters will need to be secured according to your
network policies. If you are using a username/password and SSL for an external
Elasticsearch cluster then the URL should be the format:

https://username:password@elastic.example.com:9200

Where username is the username for Elasticsearch (default "elastic") and
password is the password for the login you configured.

After setup is completed, you can copy over a certificate for the SSL
connection for the Elasticsearch cluster. Please see the documentation for
more details on how to do this.
******************************************************************************

EOF

  read -p "Optional Elasticsearch URL (Default: http://elasticsearch:9200): " ELASTIC_SERVER_URL
fi

if [[ ! "$ELASTIC_SERVER_URL" ]]; then
    echo "No Elasticsearch URL provided. Using default."
else
    echo "Setting Elasticsearch URL to: $ELASTIC_SERVER_URL"
    export ELASTIC_SERVER_URL
fi

docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt 2>/dev/null

# Use standard Elasticsearch image unless overriden.
if [[ -z "${ELASTIC_SERVER_URL}" ]]
then
  echo "Starting default Elasticsearch database. Please wait a bit."
  ../start_scripts/start_elastic.sh
  temp_cnt=30
  while [[ ${temp_cnt} -gt 0 ]];
  do
      printf "\rWaiting %2d second(s) for Elasticsearch to start and settle down." ${temp_cnt}
      sleep 1
      ((temp_cnt--))
  done
else
  echo "Using remote Elasticsearch URL for database: $ELASTIC_SERVER_URL"
fi


./setup_scripts/setup_server.sh
if [[ $? -eq 1 ]]
then
  echo "Server setup did not run. Aborting install."
  exit 1
fi

./setup_scripts/setup_keys.sh
if [[ $? -eq 1 ]]
then
  echo "Server and node key setup did not run. Aborting install."
  exit 1
fi

./setup_scripts/setup_ssl.sh
if [[ $? -eq 1 ]]
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
if [[ $? -eq 1 ]]
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

./start_rabbit.sh
./start_server.sh

Your randomly generated password for the admin account is is located under:

$PWD/setup_data/admin.password.txt
******************************************************************************

EOF
