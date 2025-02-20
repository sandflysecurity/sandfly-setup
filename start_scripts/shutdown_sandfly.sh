#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# This script will shut down all Docker containers on the system, shutting
# down the Sandfly containers in the correct order to minimize problems and
# messages in error logs.
#
# This script may be run on server and node hosts.

# If running under Podman, delete systemd container files
# 
podman_command=$(command -v podman)
if [ ! -z "${podman_command}" ]; then
    docker_engine=$(docker version | grep "^Client:" | awk '{print tolower($2)}')
    if [ "$docker_engine" != "docker" ]; then
        SYSTEM_CTL="systemctl --user"
        TARGET_DIR=~/.config/containers/systemd
        if [ $(id -u) -eq 0 ]; then
            SYSTEM_CTL="systemctl"
            TARGET_DIR=/etc/containers/systemd
            echo "*** Running as rootful user  : [$USER] : [$SYSTEM_CTL] : [$TARGET_DIR]"
        else
            echo "*** Running as rootless user : [$USER] : [$SYSTEM_CTL] : [$TARGET_DIR]"
        fi
        if [ -d $TARGET_DIR ]; then
            # delete systemd container files from $TARGET_DIR
            for sandfly_file in ${TARGET_DIR}/sandfly-*.container; do
                if [ -f $sandfly_file ]; then
                    echo "*** Delete $sandfly_file"
                    rm -f $sandfly_file
                fi
            done
            echo "*** $SYSTEM_CTL daemon-reload"
            $SYSTEM_CTL daemon-reload
        fi
        # delete systemd container files from script directory
        MY_DIR=$(dirname "${BASH_SOURCE[0]}")
        for sandfly_file in ${MY_DIR}/sandfly-*.container; do
            if [ -f $sandfly_file ]; then
                echo "*** Delete $sandfly_file"
                rm -f $sandfly_file
            fi
        done
    fi
fi

server=$(docker container ps -qf "name=sandfly-server")
if [[ -n "$server" ]]; then
    echo "* Sandfly server is running on this system. Stopping..."
    docker update --restart=no $server >/dev/null 2>&1
    docker stop $server
    echo "* Sandfly server stopped."
fi

postgres=$(docker container ps -qf "name=sandfly-postgres")
if [[ -n "$postgres" ]]; then
    echo "* Postgres is running on this system. Stopping..."
    docker update --restart=no $postgres >/dev/null 2>&1
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
    docker update --restart=no $rabbit >/dev/null 2>&1
    docker stop $rabbit
    echo "* RabbitMQ stopped."
fi

# Stop all node containers based on their label.
for x in $(docker container ps -qf "label=sandfly-node"); do
    printf "* Stopping node container %s\n" $x
    docker update --restart=no $x >/dev/null 2>&1
    docker stop $x
done

printf "\n\n* Done.\n\n"
