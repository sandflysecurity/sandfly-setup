#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Set CONTAINERMGR variable
. ../setup/setup_scripts/container_command.sh
if [ $? -ne 0 ]; then
    # Failed to find container runtime. The container_command script will
    # have printed an error.
    exit 1
fi

if [ ! -f ../setup/setup_data/config.server.json ]; then
    echo ""
    echo "********************************** ERROR **********************************"
    echo "*                                                                         *"
    echo "* Sandfly does not appear to be configured. Please use install.sh to      *"
    echo "* perform a new installation of Sandfly Server on this host.              *"
    echo "*                                                                         *"
    echo "* If this system is a node, not a server, use start_node.sh.              *"
    echo "*                                                                         *"
    echo "********************************** ERROR **********************************"
    echo ""
    exit 1
fi

### Start Postgres if not already running
esresult=$($CONTAINERMGR inspect --format="{{.State.Running}}" sandfly-postgres 2> /dev/null)
if [ "${esresult}z" != "truez" ]; then
    echo "*** Starting Postgres."
    ./start_postgres.sh
    if [ $? -ne 0 ]; then
        echo "*** ERROR: Error starting Postgres container; cannot proceed."
        exit 2
    fi
    # Give Postgres a few seconds to start up
    sleep 5
else
    echo "*** Postgres container already running."
fi

### Start sandfly-server if not already running
esresult=$($CONTAINERMGR inspect --format="{{.State.Running}}" sandfly-server 2> /dev/null)
if [ "${esresult}z" != "truez" ]; then
    echo "*** Starting Sandfly Server."
    ./start_server.sh
else
    echo "*** Sandfly Server container already running."
fi

### If the credentials adapter is present and configured next to the
### sandfly-setup directory, start it as well.

if [ -f ../../sandfly-credentials-adapter-setup/conf/config.json ]; then
    esresult=$($CONTAINERMGR inspect --format="{{.State.Running}}" sandfly-credentials-adapter 2> /dev/null)
    if [ "${esresult}z" != "truez" ]; then
        echo "*** Starting Sandfly Credentials Adapter."
        ../../sandfly-credentials-adapter-setup/start_credentials_adapter.sh
    else
        echo "*** Sandfly Credentials Adapter already running."
    fi
fi
