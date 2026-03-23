#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# This will delete all the SSH Hunter ssh key data from the Sandfly server.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Set CONTAINERMGR variable
. ../setup_scripts/container_command.sh
if [ $? -ne 0 ]; then
    # Failed to find container runtime. The container_command script will
    # have printed an error.
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
echo "This script will erase all SSH Hunter key data from the database."
echo "***** WARNING *****"
echo ""
read -p "Are you sure you want to do this (type YES)? " RESPONSE
if [[ "$RESPONSE" = "YES" ]]; then
    echo "db clear started"
    $CONTAINERMGR exec sandfly-postgres psql -U sandfly -c "TRUNCATE TABLE ssh_public_keys, user_ssh_authorized_keys, user_ssh_authorized_keys_entry, ssh_public_keys_tags;"
else
    echo "Response wasn't 'YES', aborting SSH Hunter clear."
fi
