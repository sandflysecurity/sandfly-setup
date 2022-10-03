#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2022 Sandfly Security LTD, All Rights Reserved.

# This script is for building an offline Sandfly installer package
# for use on systems that do not have connectivity to the Internet.
# Associated offline installation documentation is found at:
# https://support.sandflysecurity.com/support/solutions/articles/72000570042-offline-installation

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SF_VERSION=${SANDFLY_VERSION:-$(cat ../../VERSION)}
PG_VERSION=${POSTGRES_VERSION:-$(grep -oP '^postgres:\K([0-9.]+)' ../../start_scripts/start_postgres.sh)}
WHOAMI=$(whoami)

# See if we can run Docker
if [ $WHOAMI != "root" ]; then
    grep -E '^docker:' /etc/group | grep -E "\b$WHOAMI\b(,|\s|$)" >/dev/null 2>&1 ||
    { grep -E '^sudo:' /etc/group | grep -E "\b$WHOAMI\b(,|\s|$)" >/dev/null 2>&1 || \
    { echo "This script must be run as root or as a user with access to the Docker daemon."; exit 1; } }
fi
which docker >/dev/null 2>&1 || { echo "Unable to locate docker binary; please install Docker."; exit 1; }
docker version >/dev/null 2>&1 || { echo "Unable to connect to the Docker daemon."; exit 1; }

DOCKER_BASE=quay.io/sandfly
IMAGELIST=""

# Build up the list of images to pass to `docker image save`, and pull them.
for x in sandfly-node sandfly-rabbit sandfly-server; do
    IMAGE=${DOCKER_BASE}/${x}:${SF_VERSION}
    IMAGELIST="${IMAGELIST} ${IMAGE}"
    docker pull $IMAGE
done

# Pull PostgreSQL image
IMAGELIST="${IMAGELIST} postgres:${PG_VERSION}"

docker pull postgres:${PG_VERSION}

echo "Saving images: $IMAGELIST"
echo "**"
echo "** Exporting Docker images to: ~/sandfly-docker-images-$SF_VERSION.tgz"
echo "**"
echo "** To restore on a system, use:"
echo "** zcat sandfly-docker-images-$SF_VERSION.tgz | docker image load"
echo "**"
echo "This will take a few minutes."

docker image save $IMAGELIST | gzip > ~/sandfly-docker-images-$SF_VERSION.tgz

echo "Done!"
echo
