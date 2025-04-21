#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Cleans out Sandfly docker images so we don't accumulate old versions,
# or to force a reload of the images.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Cleanly shut down Sandfly
../start_scripts/shutdown_sandfly.sh

# Stop and delete all sandfly containers (should already be stopped from
# the above script, but we'll stop again just in case).

# Possible leftover management container from install/setup
docker update --restart=no sandfly-server-mgmt >/dev/null 2>&1
docker stop sandfly-server-mgmt >/dev/null 2>&1
docker rm sandfly-server-mgmt >/dev/null 2>&1

# Server
docker update --restart=no sandfly-server >/dev/null 2>&1
docker stop sandfly-server >/dev/null 2>&1
docker rm sandfly-server >/dev/null 2>&1

# Postgres
docker update --restart=no sandfly-postgres >/dev/null 2>&1
docker stop sandfly-postgres >/dev/null 2>&1
docker rm sandfly-postgres >/dev/null 2>&1

# Rabbit very likely not in use anymore, but in case upgrading
# from an old version...
docker update --restart=no sandfly-rabbit >/dev/null 2>&1
docker stop sandfly-rabbit >/dev/null 2>&1
docker rm sandfly-rabbit >/dev/null 2>&1

# Nodes
for x in $(docker container ps -aqf "label=sandfly-node"); do
    docker update --restart=no $x >/dev/null 2>&1
    docker stop $x >/dev/null 2>&1
    docker rm $x >/dev/null 2>&1
done

# Delete sandfly images
docker rmi -f $(docker images quay.io/sandfly/sandfly -q) 2>/dev/null

# Delete the postgres images. We won't -f in case other containers are using
# them. Try to delete both the full version of the name and the short
# name to handle docker and podman.
docker rmi $(docker images docker.io/library/postgres -q) 2>/dev/null
docker rmi $(docker images postgres -q) 2>/dev/null

# Clean up anything left dangling.
docker image prune -f 2>/dev/null
