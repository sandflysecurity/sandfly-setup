#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2022-2024 Sandfly Security LTD, All Rights Reserved.

# This script deletes EVERYTHING. Sandfly config, database, any other unused
# Docker volumes on the host, etc.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"
SETUP_DATA_DIR=../setup_data
SETUP_DIR=..

# See if we can run Docker
which docker >/dev/null 2>&1 || { echo "Unable to locate docker binary; please install Docker."; exit 1; }
docker version >/dev/null 2>&1 || { echo "This script must be run as root or as a user with access to the Docker daemon."; exit 1; }

echo ""
echo "---- DANGER ---- DANGER ---- DANGER ---- DANGER ---- DANGER ---- DANGER ----"
echo ""
echo "  This script will delete ALL Sandfly and Docker data on this host."
echo ""
echo "  This includes the Sandfly database, configuration, encryption keys,"
echo "  etc. NO backups will be made. Only use this script if you want to delete"
echo "  ALL data."
echo ""
echo "---- DANGER ---- DANGER ---- DANGER ---- DANGER ---- DANGER ---- DANGER ----"
echo ""

echo "** Do you really want to do this? If you want to continue, type (in uppercase):"
echo "**    YES I WANT TO DELETE EVERYTHING"
read -p "Confirm: " CONFIRMATION

if [ "$CONFIRMATION" != "YES I WANT TO DELETE EVERYTHING" ]
then
    echo ""
    echo "** CANCELED"
    echo "** User did not type YES I WANT TO DELETE EVERYTHING"
    echo ""
    exit 1
fi

# Our existing clean script will wipe containers and images
$SETUP_DIR/clean_docker.sh

# Now blow away our docker volume.
docker volume rm sandfly-pg14-db-vol

# Now blow away our docker network.
docker network rm sandfly-net

# Delete config
rm -f $SETUP_DATA_DIR/*.json $SETUP_DATA_DIR/*.txt

echo ""
echo "Done."
echo ""
