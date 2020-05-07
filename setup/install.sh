#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2020 Sandfly Security LTD, All Rights Reserved.

VERSION=$(cat ../VERSION)
export SANDFLY_MGMT_DOCKER_IMAGE="docker.io/sandfly/sandfly-server-mgmt:$VERSION"

clear
cat << EOF

Installing Sandfly server version $VERSION.

Copyright (c)2016-$(date +%Y) Sandfly Security Ltd.

Welcome to the Sandfly $VERSION server setup.

EOF

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

cat << EOF

************************************************************************************************
Elasticsearch Database Setup

If you want to use an external Elasticsearch cluster, please fill in the field below with the
URL. Otherwise, just hit enter and we'll use the default URL.

The default URL is internally routed only with the Sandfly server and is not reachable over
the network.

External Elasticsearch clusters will need to be secured according to your network policies. If
you are using a username/password and SSL for an external Elasticsearch cluster then the URL
should be the format:

https://username:password@elastic.example.com:9200

Where username is the username for Elasticsearch (default "elastic") and password is the password
for the login you configured.

After setup is completed, you can copy over a certificate for the SSL connection for the
Elasticsearch cluster. Please see the documentation for more details on how to do this.

************************************************************************************************

EOF

read -p "Optional Elasticsearch URL (Default: http://elasticsearch:9200): " ELASTIC_SERVER_URL
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

./setup_scripts/setup_pgp_keys.sh
if [[ $? -eq 1 ]]
then
  echo "PGP key setup did not run. Aborting install."
  exit 1
fi

./setup_scripts/setup_ssl.sh
if [[ $? -eq 1 ]]
then
  echo "SSL setup did not run. Aborting install."
  exit 1
fi

cat << EOF

************************************************************************************************
Make Signed SSL Key?

If the Sandfly server is able to be seen on the Internet, we can generate a signed key using
EFF's Let's Encrypt Bot. Answer below if you'd like to do this.

************************************************************************************************

EOF
read -p "Generate signed SSL keys (type YES)? " RESPONSE
if [[ "$RESPONSE" = "YES" ]]
then
    echo "Starting key signing script"
    ./setup_scripts/setup_ssl_signed.sh
fi

cat << EOF

************************************************************************************************
Setup Complete!

Your setup is complete. Please see below for the path to the admin password to login.

You will need to go to $PWD/start_scripts and run the following to start the server:

./start_rabbit.sh
./start_server.sh

Your randomly generated password for the admin account is is located under:

$PWD/setup_data/admin.password.txt

************************************************************************************************

EOF

