#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2022 Sandfly Security LTD, All Rights Reserved.

# This script will shut down all Docker containers on the system, shutting
# down the Sandfly containers in the correct order to minimize problems and
# messages in error logs.
#
# This script may be run on server and node hosts.

server=$(docker container ps -qf "name=sandfly-server")
if [[ -n "$server" ]]; then
    echo "* Sandfly server is running on this system. Stopping..."
    docker update --restart=no $server
    docker stop $server
    echo "* Sandfly server stopped."
fi

postgres=$(docker container ps -qf "name=sandfly-postgres")
if [[ -n "$postgres" ]]; then
    echo "* Postgres is running on this system. Stopping..."
    docker update --restart=no $postgres
    docker exec -it --user 999 $postgres pg_ctl stop
    echo ""
    
    # A stop at this point is usually unnecessary as the container will end
    # when the postgres process stops, but we'll include it to be safe.
    docker stop $postgres
    echo "* Postgres server stopped."
fi

# Rabbit container is no longer used in 5.0 and later, but we will leave this
# stop command in place for some time in case this version of sandfly-setup is
# being used during an upgrade of an existing system.
rabbit=$(docker container ps -qf "name=sandfly-rabbit")
if [[ -n "$rabbit" ]]; then
    echo "* RabbitMQ is running on this system. Stopping..."
    docker update --restart=no $rabbit
    docker stop $rabbit
    echo "* RabbitMQ stopped."
fi

# Stop all node containers based on their label.
for x in $(docker container ps -qf "label=sandfly-node"); do
    printf "* Stopping node container %s\n" $x
    docker update --restart=no $x
    docker stop $x
done

printf "\n\n* Done.\n\n"
