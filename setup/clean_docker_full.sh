#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Cleans out ALL containers and images.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Set CONTAINERMGR variable
. ./setup_scripts/container_command.sh
if [ $? -ne 0 ]; then
    # Failed to find container runtime. The container_command script will
    # have printed an error.
    exit 1
fi

if [ -z "$SKIP_SANDFLY_WARNING" ]; then
    echo "****************************************************************"
    echo "* This script will delete ALL containers and images running    *"
    echo "* on this host, NOT only Sandfly containers. If this is what   *"
    echo "* you want to do, enter:                                       *"
    echo "*                                                              *"
    echo "*    DELETE ALL CONTAINERS                                     *"
    echo "*                                                              *"
    echo "* at the prompt.                                               *"
    echo "****************************************************************"
    echo ""
    echo "Enter 'DELETE ALL CONTAINERS' to continue:"
    read confirmation

    if [ "$confirmation" != "DELETE ALL CONTAINERS" ]; then
        echo "Canceling. User did not enter exact confirmation text."
        exit 1
    fi
fi

# Cleanly shut down Sandfly
../start_scripts/shutdown_sandfly.sh

# Stop all - just in case anything survived the shutdown script.
$CONTAINERMGR stop $($CONTAINERMGR ps -a -q) 2>/dev/null
# Delete all containers
$CONTAINERMGR rm -f $($CONTAINERMGR ps -a -q) 2>/dev/null
# Delete all images
$CONTAINERMGR rmi -f $($CONTAINERMGR images -q) 2>/dev/null
