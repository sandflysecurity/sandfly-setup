#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# This script will shut down all Docker containers on the system, shutting
# down the Sandfly containers in the correct order to minimize problems and
# messages in error logs.
#
# This script may be run on server and node hosts.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Set CONTAINERMGR variable
. ../setup/setup_scripts/container_command.sh
if [ $? -ne 0 ]; then
    # Failed to find container runtime. The container_command script will
    # have printed an error.
    exit 1
fi

# If running under Podman, delete systemd container files
if [ "$CONTAINERMGR" = "podman" ]; then
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

server=$($CONTAINERMGR container ps -qf "name=sandfly-server")
if [[ -n "$server" ]]; then
    echo "* Sandfly server is running on this system. Stopping..."
    $CONTAINERMGR update --restart=no $server >/dev/null 2>&1
    $CONTAINERMGR stop $server
    echo "* Sandfly server stopped."
fi

postgres=$($CONTAINERMGR container ps -qf "name=sandfly-postgres")
if [[ -n "$postgres" ]]; then
    echo "* Postgres is running on this system. Stopping..."
    $CONTAINERMGR update --restart=no $postgres >/dev/null 2>&1

    # Wait for remaining database activity to stop
    timeout_seconds=900         # 15 minutes
    start_time=$(date '+%s')
    while true; do
        # If the user requested we skip this via environment, do so.
        if [ -n "$SKIP_DB_ACTIVITY_CHECK" ]; then
            break
        fi

        active_count=$($CONTAINERMGR exec sandfly-postgres psql -U postgres \
            -t -c "SELECT count(*) FROM pg_stat_activity \
                WHERE usename='sandfly' AND state <> 'idle' \
                AND pid <> pg_backend_pid();" \
            | xargs)
        if [ -z "$active_count" ]; then
            echo "*** ERROR: couldn't get postgres activity status."
            break
        fi

        if [ "$active_count" -eq 0 ]; then
            break
        fi

        if [ $(( $(date '+%s') - $start_time)) -gt $timeout_seconds ]; then
            echo "*** ERROR: timeout exceeded; issuing stop command now."
            break
        fi

        # Otherwise, wait longer...
        echo "...waiting for database activity to settle ($active_count transaction(s) active)."
        sleep 10
    done

    $CONTAINERMGR exec -it --user 999 $postgres pg_ctl stop
    echo ""

    # A stop at this point is usually unnecessary as the container will end
    # when the postgres process stops, but we'll include it to be safe.
    $CONTAINERMGR stop $postgres
    echo "* Postgres server stopped."
fi

# Stop all node containers based on their label.
for x in $($CONTAINERMGR container ps -qf "label=sandfly-node"); do
    printf "* Stopping node container %s\n" $x
    $CONTAINERMGR update --restart=no $x >/dev/null 2>&1
    $CONTAINERMGR stop $x
done

printf "\n\n* Done.\n\n"
