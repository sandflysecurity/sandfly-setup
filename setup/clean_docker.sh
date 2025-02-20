#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Cleans out all docker images. Required to do this before upgrading to get rid of stale containers.

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

