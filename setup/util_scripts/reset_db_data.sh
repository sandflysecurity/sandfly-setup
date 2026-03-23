#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# This will delete all the results, errors, and audit log data from the
# Sandfly server. This is useful if the system got flooded with alarms or
# other data and you want to quickly get rid of all of it and start fresh.
# All other config data will remain untouched.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Set CONTAINERMGR variable
. ../setup_scripts/container_command.sh
if [ $? -ne 0 ]; then
    # Failed to find container runtime. The container_command script will
    # have printed an error.
    exit 1
fi

# Check the state of the sandfly-server container
esresult=$($CONTAINERMGR inspect --format="{{.State.Running}}" sandfly-server 2> /dev/null)
if [ "${esresult}z" = "truez" ]; then
    echo ""
    echo "****************************** ERROR ******************************"
    echo "* The Sandfly server container is running.                        *"
    echo "*                                                                 *"
    echo "* The container must be stopped with the following command:       *"
    echo "*   $CONTAINERMGR stop sandfly-server                                    *"
    echo "*                                                                 *"
    echo "* IMPORTANT: That command will take the UI and scanning offline!  *"
    echo "*                                                                 *"
    echo "* Then run this script again. Once it has finished, restore       *"
    echo "* the Sandfly server container with the following command:        *"
    echo "*   $CONTAINERMGR start sandfly-server                                   *"
    echo "****************************** ERROR ******************************"
    echo ""
    exit 1
fi

# Check the state of the sandfly-postgres container
esresult=$($CONTAINERMGR inspect --format="{{.State.Running}}" sandfly-postgres 2> /dev/null)
if [ "${esresult}z" != "truez" ]; then
    echo ""
    echo "****************************** ERROR ******************************"
    echo "* The Sandfly Postgres container is not running.                  *"
    echo "*                                                                 *"
    echo "* Please start the container with the following script:           *"
    echo "*   ~/sandfly-setup/start_scripts/start_postgres.sh               *"
    echo "*                                                                 *"
    echo "* Then run this script again.                                     *"
    echo "****************************** ERROR ******************************"
    echo ""
    exit 1
fi

echo "***** WARNING *****"
echo "This script will erase your results, error, and audit log data."
echo "***** WARNING *****"
echo ""
read -p "Are you sure you want to do this (type YES)? " RESPONSE
if [[ "$RESPONSE" = "YES" ]]; then
    echo "db clear started"
    $CONTAINERMGR exec sandfly-postgres psql -U sandfly -c "TRUNCATE TABLE results, results_json, results_updates, audit_log, errors;"
else
    echo "Aborting clear init."
fi
