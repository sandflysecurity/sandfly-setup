#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2022-2024 Sandfly Security LTD, All Rights Reserved.

# This script is for building an offline Sandfly installer package
# for use on systems that do not have connectivity to the Internet.
# Associated offline installation documentation is found at:
# https://support.sandflysecurity.com/support/solutions/articles/72000570042-offline-installation

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SF_VERSION=${SANDFLY_VERSION:-$(cat ../../VERSION)}
PG_VERSION=${POSTGRES_VERSION:-$(grep -oP 'POSTGRES_VERSION:-\K([0-9.]+)' ../../start_scripts/start_postgres.sh)}
WHOAMI=$(whoami)

if ! command -v docker >/dev/null 2>&1; then
    echo "No docker command found. docker or podman-docker must be installed."
    exit 1
fi

# See if we can run Docker (or the podman compatability shim) as the current
# user.
docker version >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "This script must be run as root or as a user with access to the Docker daemon."
    exit 1
fi

DOCKER_BASE=quay.io/sandfly
IMAGELIST=""

# Build up the list of images to pass to `docker image save`, and pull them.
for x in sandfly; do
    IMAGE=${DOCKER_BASE}/${x}:${SF_VERSION}
    IMAGELIST="${IMAGELIST} ${IMAGE}"
    docker pull $IMAGE
done

# Pull PostgreSQL image
IMAGELIST="${IMAGELIST} docker.io/library/postgres:${PG_VERSION}"

docker pull docker.io/library/postgres:${PG_VERSION}

echo "Saving images: $IMAGELIST"
echo "**"
echo "** Exporting Docker images to: ~/sandfly-docker-images-$SF_VERSION.tgz"
echo "**"
echo "** To restore on a system, use:"
echo "** zcat sandfly-docker-images-$SF_VERSION.tgz | docker image load"
echo "**"
echo "This will take a few minutes."

# If "docker" is really podman, we need to use the -m argument to the save
# command.
SAVECMD="docker image save"
if command -v podman >/dev/null 2>&1; then
    SAVECMD="podman image save -m"
fi

$SAVECMD $IMAGELIST | gzip > ~/sandfly-docker-images-$SF_VERSION.tgz

echo "Done!"
echo
