#!/usr/bin/env bash

# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# This script will install the Sandfly server. By default, it will run
# through an interactive setup process.
#
# The script is also capable of performing a non-interactive automated all-
# in-one single-system setup. To perform the automated setup, set the
# environment variable SANDFLY_SETUP_AUTO_HOSTNAME to the hostname of the
# Sandfly server.
#
# By default, the script will use the version from the ../VERSION file
# and will pull images from the quay.io/sandfly Docker repository. To
# override these defaults, set SANDFLY_SETUP_VERSION to the version tag
# on the sandfly-server-mgmt Docker image and/or set
# SANDFLY_SETUP_DOCKER_BASE to the prefix of the Docker image tag to use.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"
SETUP_DATA_DIR=./setup_data

VERSION=${SANDFLY_SETUP_VERSION:-$(cat ../VERSION)}
DOCKER_BASE=${SANDFLY_SETUP_DOCKER_BASE:-quay.io/sandfly}
export SANDFLY_MGMT_DOCKER_IMAGE="$DOCKER_BASE/sandfly${IMAGE_SUFFIX}:$VERSION"

# Set CONTAINERMGR variable
. ./setup_scripts/container_command.sh
if [ $? -ne 0 ]; then
    # Failed to find container runtime. The container_command script will
    # have printed an error.
    exit 1
fi

# Sandfly already installed?
if [ -f ${SETUP_DATA_DIR}/config.server.json -o -f ${SETUP_DATA_DIR}/config.server.env ]; then
    echo ""
    echo "********************************** ERROR **********************************"
    echo "*                                                                         *"
    echo "* Sandfly is already installed (there is a config file in the setup_data  *"
    echo "* directory).                                                             *"
    echo "*                                                                         *"
    echo "* If you are upgrading to a new version of Sandfly, please follow the     *"
    echo "* instructions at:                                                        *"
    echo "* https://docs.sandflysecurity.com/docs/upgrading-sandfly                 *"
    echo "*                                                                         *"
    echo "* If you wish to completely delete your old Sandfly configuration and     *"
    echo "* database, please use delete_sandfly_installation.sh in the util_scripts *"
    echo "* directory.                                                              *"
    echo "*                                                                         *"
    echo "********************************** ERROR **********************************"
    echo ""
    exit 1
fi

cat << "__EOF__"


 _____                 _  __ _         _____                      _ _
/  ___|               | |/ _| |       /  ___|                    (_) |
\ `--.  __ _ _ __   __| | |_| |_   _  \ `--.  ___  ___ _   _ _ __ _| |_ _   _
 `--. \/ _` | '_ \ / _` |  _| | | | |  `--. \/ _ \/ __| | | | '__| | __| | | |
/\__/ / (_| | | | | (_| | | | | |_| | /\__/ /  __/ (__| |_| | |  | | |_| |_| |
\____/ \__,_|_| |_|\__,_|_| |_|\__, | \____/ \___|\___|\__,_|_|  |_|\__|\__, |
                     .          __/ |              .                     __/ |
                    //         |___/               \\                   |___/
                   //                               \\
                  //                                 \\
                 //                _._                \\
              .---.              .//|\\.              .---.
    ________ / .-. \_________..-~ _.-._ ~-..________ / .-. \_________ -sr
             \ ~-~ /   /H-     `-=.___.=-'     -H\   \ ~-~ /
               ~~~    / H          [H]          H \    ~~~
                     / _H_         _H_         _H_ \
                       UUU         UUU         UUU
__EOF__

# Is this an automated install?
SANDFLY_AUTO=NO
[ -n "$SANDFLY_SETUP_AUTO_HOSTNAME" -a -n "$SANDFLY_SETUP_AUTO_ADMIN_PASSWORD" ] && export SANDFLY_AUTO=YES

# But if we only have one or the other, error
if [ -n "$SANDFLY_SETUP_AUTO_HOSTNAME" -a "$SANDFLY_AUTO" = "NO" ]; then
    echo ""
    echo "*********************************** ERROR ***********************************"
    echo "*                                                                           *"
    echo "* SANDFLY_SETUP_AUTO_HOSTNAME is set, but SANDFLY_SETUP_AUTO_ADMIN_PASSWORD *"
    echo "* is not. For an automated install, both are required.                      *"
    echo "*                                                                           *"
    echo "*********************************** ERROR ***********************************"
    echo ""
    exit 1
fi
if [ -n "$SANDFLY_SETUP_AUTO_ADMIN_PASSWORD" -a "$SANDFLY_AUTO" = "NO" ]; then
    echo ""
    echo "*********************************** ERROR ***********************************"
    echo "*                                                                           *"
    echo "* SANDFLY_SETUP_AUTO_ADMIN_PASSWORD is set, but SANDFLY_SETUP_AUTO_HOSTNAME *"
    echo "* is not. For an automated install, both are required.                      *"
    echo "*                                                                           *"
    echo "*********************************** ERROR ***********************************"
    echo ""
    exit 1
fi

cat << EOF

Installing Sandfly server version $VERSION.

Copyright (c) Sandfly Security Ltd.

Welcome to the Sandfly $VERSION server setup.

EOF

# Sandfly Postgres Docker volume already exists? Check the current volume name
# and the legacy version-specific names.
for vol in sandfly-pg-db-vol sandfly-pg18-db-vol sandfly-pg14-db-vol; do
    if $CONTAINERMGR volume inspect $vol >/dev/null 2>&1; then
        echo ""
        echo "********************************** ERROR **********************************"
        echo "*                                                                         *"
        echo "* Sandfly is already installed (the database Docker volume,               *"
        printf "* %-72s*\n" "$vol, exists)."
        echo "*                                                                         *"
        echo "* If you are upgrading to a new version of Sandfly, please follow the     *"
        echo "* instructions at:                                                        *"
        echo "* https://docs.sandflysecurity.com/docs/upgrading-sandfly                 *"
        echo "*                                                                         *"
        echo "* If you wish to completely delete your old Sandfly configuration and     *"
        echo "* database, please use delete_sandfly_installation.sh in the util_scripts *"
        echo "* directory.                                                              *"
        echo "*                                                                         *"
        echo "********************************** ERROR **********************************"
        echo ""
        exit 1
    fi
done

# Are we using Podman?
if [ "$CONTAINERMGR" = "podman" ]; then
    if [ $(id -u) -eq 0 ]; then
        echo ""
        echo "********************************* WARNING *********************************"
        echo "*                                                                         *"
        echo "* You appear to be running the Podman engine in rootful user mode.        *"
        echo "*                                                                         *"
        echo "* To install using Podman as a rootful user, we will need to do the       *"
        echo "* following actions                                                       *"
        echo "*                                                                         *"
        echo "* 1. Create container files in the /etc/containers/systemd folder         *"
        echo "*    to allow systemd to start the containers at boot time                *"
        echo "*                                                                         *"
        echo "********************************* WARNING *********************************"
        echo ""
    else
        echo ""
        echo "********************************* WARNING *********************************"
        echo "*                                                                         *"
        echo "* You appear to be running the Podman engine in rootless user mode.       *"
        echo "*                                                                         *"
        echo "* To install using Podman as a rootless user, we will need to do the      *"
        echo "* following actions                                                       *"
        echo "*                                                                         *"
        echo "* 1. Modify sysctl.conf to allow an unprivileged process to bind to       *"
        echo "*    ports 80 and 443 (requires root access via sudo)                     *"
        echo "* 2. Enable Linger mode for the current user to prevent containers from   *"
        echo "*    shutting down at logout and to start containers at boot time (may    *"
        echo "*    require root access via sudo)                                        *"
        echo "* 3. Create container files in the ~/.config/containers/systemd folder    *"
        echo "*    to allow systemd to start the containers at boot time                *"
        echo "* 4. If Podman is version 5 or later and the default Rootless Network     *"
        echo "*    Cmd is configured to use 'slirp4netns' we will create or modify the  *"
        echo "*    ~/.config/containers/containers.conf file to use 'pasta'             *"
        echo "*    as the default_rootless_network_cmd.                                 *"
        echo "*                                                                         *"
        echo "********************************* WARNING *********************************"
        echo ""
    fi

    read -p "Continue installing under Podman (type YES)? " PODMAN_RESPONSE
    if [ "$PODMAN_RESPONSE" != "YES" ]; then
        echo ""
        echo "Aborting install."
        exit 1
    fi

    # change unprivileged_port_start to allow non-root process to bind to ports
    #   80 and 443 (requires sudo)
    # enable Linger for non-root user
    # configure 'pasta' as the default_rootless_network_cmd
    #
    if [ $(id -u) -ne 0 ]; then
        live_port_start=$(sudo sysctl --values net.ipv4.ip_unprivileged_port_start)
        if [ ! -z "${live_port_start}" ]; then
            if [ $live_port_start -gt 80 ]; then
                echo "Configure sysctl to allow containers that bind to ports < 1024"
                sudo sysctl net.ipv4.ip_unprivileged_port_start=80
            fi
        fi

        conf_port_start=$(cat /etc/sysctl.conf | grep net.ipv4.ip_unprivileged_port_start)
        if [ -z "${conf_port_start}" ]; then
            echo "Configure /etc/sysctl.conf to allow containers that bind to ports < 1024"
            echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee -a /etc/sysctl.conf
        fi

        linger_status=$(loginctl show-user $USER | grep ^Linger | awk -F= '{print $2}')
        if [ "$linger_status" = "no" ]; then
            echo "Enable Linger for user $USER"
            loginctl enable-linger $USER 2>/dev/null
            if [ $? -ne 0 ]; then
                sudo loginctl enable-linger $USER
            fi
        fi

        # Make sure we are using 'pasta' as the default rootless network manager
        ./setup_scripts/podman_rootless_network_cmd.sh
        if [ "$?" -ne 0 ]; then
            echo "Error must use 'pasta' as the rootlessNetworkCmd."
            exit 1
        fi
    fi
fi

[ "$SANDFLY_AUTO" = "YES" ] && cat << EOF
This will be a fully-automated setup.

Hostname: $SANDFLY_SETUP_AUTO_HOSTNAME
Sandfly Image: $SANDFLY_MGMT_DOCKER_IMAGE

EOF

./setup_scripts/create_sandfly_net.sh
if [ "$?" -ne 0 ]; then
  echo "Error creating sandfly-net."
  exit 1
fi

$CONTAINERMGR rm sandfly-server-mgmt 2>/dev/null

# Load images if offline bundle is present and not already loaded
./setup_scripts/load_images.sh
if [ "$?" -ne 0 ]; then
  echo "Error loading container images."
  exit 1
fi

# Generate configuration environment files
# The special value "skip" for admin password will leave it unset.
if [ "$SANDFLY_AUTO" = "YES" ]; then
    if [ "$SANDFLY_SETUP_AUTO_ADMIN_PASSWORD" = "skip" ]; then
        ./setup_scripts/setuphelper install -output-dir setup_data \
            -skipadminpw \
            -hostname "$SANDFLY_SETUP_AUTO_HOSTNAME" \
            -tls-mode self_signed "$@"
    else
        ./setup_scripts/setuphelper install -output-dir setup_data \
            -admin-password "$SANDFLY_SETUP_AUTO_ADMIN_PASSWORD" \
            -hostname "$SANDFLY_SETUP_AUTO_HOSTNAME" \
            -tls-mode self_signed "$@"
    fi
    if [ "$?" -ne 0 ]; then
        echo "Error generating configuration environment files."
        exit 1
    fi
else
    ./setup_scripts/setuphelper install -output-dir setup_data "$@"
    if [ "$?" -ne 0 ]; then
        echo "Error generating configuration environment files."
        exit 1
    fi
fi

cat << EOF

******************************************************************************
Server Setup Complete!

Before you can add hosts and scan with Sandfly, you need
to set up one or more scanning nodes as well.

To start the server, go to $(realpath $PWD/../start_scripts)
and run the Sandfly start script:

./start_sandfly.sh

*** YOU MUST ALSO START A SCANNING NODE TO USE SANDFLY.
*** See the installation documentation for instructions on setting up the
*** node on a separate server (recommended for production deployments),
*** or start the node on this machine with the ./start_node.sh script
*** in the start_scripts directory.

******************************************************************************

EOF
