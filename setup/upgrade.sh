#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SETUP_DATA=../setup/setup_data
VERSION=${SANDFLY_VERSION:-$(cat ../VERSION)}
IMAGE_BASE=${SANDFLY_IMAGE_BASE:-quay.io/sandfly}

# Use standard docker image unless overriden.
if [[ -z "${SANDFLY_MGMT_DOCKER_IMAGE}" ]]; then
  SANDFLY_MGMT_DOCKER_IMAGE="quay.io/sandfly/sandfly-server-mgmt${IMAGE_SUFFIX}:$VERSION"
fi


# See if we can run Docker
which docker >/dev/null 2>&1 || { echo "Unable to locate docker binary; please install Docker."; exit 1; }
docker version >/dev/null 2>&1 || { echo "This script must be run as root or as a user with access to the Docker daemon."; exit 1; }

docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt 2>/dev/null

# We can only upgrade if Sandfly is already installed and configured.
if [ ! -f $SETUP_DATA/config.server.json ]; then
    echo ""
    echo "********************************** ERROR **********************************"
    echo "*                                                                         *"
    echo "* Sandfly does not appear to be configured. Please use install.sh to      *"
    echo "* install Sandfly on this host, not upgrade.sh.                           *"
    echo "*                                                                         *"
    echo "********************************** ERROR **********************************"
    echo ""
    exit 1
fi

# Don't upgrade if currently running
server_result=$(docker inspect --format="{{.State.Running}}" sandfly-server 2> /dev/null)
rabbit_result=$(docker inspect --format="{{.State.Running}}" sandfly-rabbit 2> /dev/null)
if [ "${server_result}z" == "truez" -o "${rabbit_result}z" == "truez" ]; then
    echo ""
    echo "********************************** ERROR **********************************"
    echo "*                                                                         *"
    echo "* Sandfly is currently running, so cannot be upgraded. Please stop all    *"
    echo "* Sandfly containers (e.g. \`docker ls\` to get list, then for each name,   *"
    echo "* \`docker stop <name>\`).                                                  *"
    echo "*                                                                         *"
    echo "********************************** ERROR **********************************"
    echo ""
    exit 1
fi

# jq might not be available on the outer Docker host, so we'll do a simple grep
# to make sure the config version isn't set yet (and thus needs to be upgraded)
grep -q \"config_version\":\ 2, $SETUP_DATA/config.server.json
if [ $? == 0 ]; then
    echo ""
    echo "********************************** ERROR **********************************"
    echo "*                                                                         *"
    echo "* Sandfly appears to already be upgraded to the correct version.          *"
    echo "*                                                                         *"
    echo "********************************** ERROR **********************************"
    echo ""
    exit 1
fi

# Get the old configuration.
CONFIG_JSON=$(cat $SETUP_DATA/config.server.json)
export CONFIG_JSON

# Back up the old config
mkdir -p $SETUP_DATA/backup
cp $SETUP_DATA/*.json $SETUP_DATA/backup

# Start the Postgres server
# The first time we start Postgres, we need to assign a superuser password.
if [ ! -f $SETUP_DATA_DIR/postgres.admin.password.txt ]; then
    POSTGRES_ADMIN_PASSWORD=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c40)
    echo "$POSTGRES_ADMIN_PASSWORD" > $SETUP_DATA/postgres.admin.password.txt
fi
echo "*** Starting Postgres database."
../start_scripts/start_postgres.sh
if [ $? -ne 0 ]; then
    echo "*** ERROR: Error starting Postgres container; cannot proceed."
    exit 1
fi
sleep 5

### Start ElasticSearch if not already running
esresult=$(docker inspect --format="{{.State.Running}}" elasticsearch 2> /dev/null)
if [ "${esresult}z" != "truez" ]; then
    echo "*** Starting ElasticSearch."
    ../start_scripts/start_elastic.sh
    if [ $? -ne 0 ]; then
        echo "*** ERROR: Error starting ElasticSearch container; cannot proceed."
        exit 2
    fi
    temp_cnt=30
    while [[ ${temp_cnt} -gt 0 ]];
    do
        printf "\rWaiting %2d second(s) for Elasticsearch to start and settle down." ${temp_cnt}
        sleep 1
        ((temp_cnt--))
    done
    echo ""
else
    echo "*** ElasticSearch container already running."
fi

docker run \
-v $PWD/setup_data:/usr/local/sandfly/install/setup_data \
--name sandfly-server-mgmt \
--network sandfly-net \
$SANDFLY_MGMT_DOCKER_IMAGE /usr/local/sandfly/install/upgrade.sh

if [ $? != 0 ]; then
    echo "*** ERROR: Upgrade process failed. See above messages for details."
    exit 1
fi

echo "Stopping Elasticsearch"
docker stop elasticsearch
docker rm elasticsearch

echo ""
echo "*********************************** INFO ***********************************"
echo "*                                                                          *"
echo "* The upgrade to Sandfly 3.1 is complete. Users, credentials, hosts,       *"
echo "* schedules, and other configuration data has been migrated to the 3.1     *"
echo "* Postgres database. You will need to run new scans (or wait for scheduled *"
echo "* scans) for results to start re-populating.                               *"
echo "*                                                                          *"
echo "* Sandfly no longer uses Elasticsearch for local data storage. When        *"
echo "* starting Sandfly 3.1, use the start_postgres.sh start script instead of  *"
echo "* the old start_elastic.sh start script. (Or use the start_sandfly.sh      *"
echo "* script which starts all necessary server components automatically.)      *"
echo "*                                                                          *"
echo "* Your Sandfly 3.0 Elasticsearch database Docker volume is still available *"
echo "* if you need to roll back the upgrade. The Sandfly 3.0 configuration      *"
echo "* files have been backed up to the setup_data/backup directory.            *"
echo "*                                                                          *"
echo "* When you are satisfied with the Sandfly 3.1 upgrade, you may permanently *"
echo "* delete your Sandfly 3.0 Elasticsearch database with the command:         *"
echo "*    docker volume rm sandfly-elastic-db-vol                               *"
echo "*                                                                          *"
echo "* Sandfly support is available at https://support.sandflysecurity.com/     *"
echo "*                                                                          *"
echo "*********************************** INFO ***********************************"
echo ""
