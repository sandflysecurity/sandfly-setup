#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SF_VERSION=${SANDFLY_VERSION:-$(cat ../../VERSION)}
PG_VERSION=${POSTGRES_VERSION:-$(grep -oP 'POSTGRES_VERSION:-\K([0-9.]+)' ../../start_scripts/start_postgres.sh)}

# If we don't have the offline package, there's nothing to do
if [ ! -f ../../docker_images/sandfly-docker-images-${SF_VERSION}.tgz ]; then
    exit
fi

# See if we can run Docker (or the podman compatability shim) as the current
# user.
docker version >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "This script must be run as root or as a user with access to the Docker daemon."
    exit 1
fi

NEED_IMAGES=0

docker inspect quay.io/sandfly/sandfly:${SF_VERSION} >/dev/null 2>&1
if [ "$?" -ne 0 ]; then
    NEED_IMAGES=1
fi

docker inspect docker.io/library/postgres:${PG_VERSION} >/dev/null 2>&1
if [ "$?" -ne 0 ]; then
    NEED_IMAGES=1
fi

# If either image didn't exist, load the bundle.
if [ "$NEED_IMAGES" -gt 0 ]; then
    echo "** Loading images from local archive:"
    echo "** ../../docker_images/sandfly-docker-images-${SF_VERSION}.tgz"
    echo "** There will be a slight delay before further output..."
    zcat ../../docker_images/sandfly-docker-images-${SF_VERSION}.tgz | \
        docker image load
    if [ "$?" -ne 0 ]; then
        echo "** ERROR loading container images."
        echo ""
        echo "****************************************************************"
        echo "*                                                              *"
        echo "* Failed to load container images from:                        *"
        echo "* sandfly-setup/docker_images/sandfly-docker-images-${SF_VERSION}.tgz  *"
        echo "*                                                              *"
        echo "* Your sandfly-setup-offline package download may have been    *"
        echo "* corrupted; please try downloading again and extracting a     *"
        echo "* fresh copy.                                                  *"
        echo "*                                                              *"
        echo "* If you wish to try an online installation, you may delete    *"
        echo "* the sandfly-docker-images-${SF_VERSION}.tgz file from the            *"
        echo "* docker_images directory and try again.                       *"
        echo "*                                                              *"
        echo "****************************************************************"
        exit 1
    fi

    # If restoring with podman, the postgres image may not get restored with
    # the prefix docker.io/library. Look for the right postgres image version
    # and tag it properly if it's not already there.
    docker inspect docker.io/library/postgres:${PG_VERSION} >/dev/null 2>&1
    if [ "$?" -ne 0 ]; then
        postgres_id=$(docker images -q postgres:${PG_VERSION})
        docker tag $postgres_id docker.io/library/postgres:${PG_VERSION}
    fi
fi
