#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Cleans out ALL docker containers and images.

if [ -z "$SKIP_SANDFLY_WARNING" ]; then
    echo "****************************************************************"
    echo "* This script will delete ALL docker containers and images     *"
    echo "* running on this host, NOT only Sandfly containers. If this   *"
    echo "* is what you want to do, enter:                               *"
    echo "*                                                              *"
    echo "*    DELETE ALL DOCKER CONTAINERS                              *"
    echo "*                                                              *"
    echo "* at the prompt.                                               *"
    echo "****************************************************************"
    echo ""
    echo "Enter 'DELETE ALL DOCKER CONTAINERS' to continue:"
    read confirmation

    if [ "$confirmation" != "DELETE ALL DOCKER CONTAINERS" ]; then
        echo "Canceling. User did not enter exact confirmation text."
        exit 1
    fi
fi

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Cleanly shut down Sandfly
../start_scripts/shutdown_sandfly.sh

# Stop all - just in case anything survived the shutdown script.
docker stop $(docker ps -a -q) 2>/dev/null
# Delete all containers
docker rm -f $(docker ps -a -q) 2>/dev/null
# Delete all images
docker rmi -f $(docker images -q) 2>/dev/null
