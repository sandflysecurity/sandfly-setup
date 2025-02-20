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

if [ -f "/snap/bin/docker" ]; then
    echo ""
    echo "****************************** ERROR ******************************"
    echo "*                                                                 *"
    echo "* A version of Docker appears to be installed via Snap.           *"
    echo "*                                                                 *"
    echo "* Sandfly is only compatible with the apt version of Docker.      *"
    echo "* Having both versions installed will conflict with Sandfly.      *"
    echo "* Please remove the snap version before installing Sandfly.       *"
    echo "*                                                                 *"
    echo "****************************** ERROR ******************************"
    echo ""
    exit 1
fi

# Sandfly already installed?
if [ -f $SETUP_DATA_DIR/config.server.json ]; then
    echo ""
    echo "********************************** ERROR **********************************"
    echo "*                                                                         *"
    echo "* Sandfly is already installed (there is a config.server.json file in     *"
    echo "* the setup_data directory).                                              *"
    echo "*                                                                         *"
    echo "* If you are upgrading to a new version of Sandfly, please use upgrade.sh *"
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
[ -n "$SANDFLY_SETUP_AUTO_HOSTNAME" ] && export SANDFLY_AUTO=YES

clear
cat << EOF
Installing Sandfly server version $VERSION.

Copyright (c) Sandfly Security Ltd.

Welcome to the Sandfly $VERSION server setup.

EOF

# See if we can run Docker
which docker >/dev/null 2>&1 || { echo "Unable to locate docker binary; please install Docker."; exit 1; }
docker version >/dev/null 2>&1 || { echo "This script must be run as root or as a user with access to the Docker daemon."; exit 1; }

# Sandfly Postgres Docker volume already exists?
docker inspect sandfly-pg14-db-vol >/dev/null 2>&1
if [[ $? -eq 0 ]]
then
    echo ""
    echo "********************************** ERROR **********************************"
    echo "*                                                                         *"
    echo "* Sandfly is already installed (the database Docker volume,               *"
    echo "* sandfly-pg14-db-vol, exists).                                           *"
    echo "*                                                                         *"
    echo "* If you are upgrading to a new version of Sandfly, please use upgrade.sh *"
    echo "*                                                                         *"
    echo "* If you wish to completely delete your old Sandfly configuration and     *"
    echo "* database, please use delete_sandfly_installation.sh in the util_scripts *"
    echo "* directory.                                                              *"
    echo "*                                                                         *"
    echo "********************************** ERROR **********************************"
    echo ""
    exit 1
fi

# Are we using the Podman engine under Docker emulation mode
#
podman_command=$(command -v podman)
if [ ! -z "${podman_command}" ]; then
    docker_engine=$(docker version | grep "^Client:" | awk '{print tolower($2)}')
    if [ "$docker_engine" != "docker" ]; then
        if [ $(id -u) -eq 0 ]; then
            echo ""
            echo "********************************* WARNING *********************************"
            echo "*                                                                         *"
            echo "* You appear to be running the Podman engine in rootful user mode.        *"
            echo "*                                                                         *"
            echo "* To install using Podman as a rootful user, we will need to do the       *"
            echo "* following actions                                                       *"
            echo "*                                                                         *"
            echo "* 1. If SELinux is running we will need to set the context of the         *"
            echo "*    setup_data folder to allow the container write access                *"
            echo "* 2. Create container files in the /etc/containers/systemd folder         *"
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
            echo "* 1. If SELinux is running we will need to set the context of the         *"
            echo "*    setup_data folder to allow the container write access                *"
            echo "* 2. Modify sysctl.conf to allow an unprivileged process to bind to       *"
            echo "*    ports 80 and 443 (requires root access via sudo)                     *"
            echo "* 3. Enable Linger mode for the current user to prevent containers from   *"
            echo "*    shutting down at logout and to start containers at boot time         *"
            echo "* 4. Create container files in the ~/.config/containers/systemd folder    *"
            echo "*    to allow systemd to start the containers at boot time                *"
            echo "* 5. If Podman is version 5 or later and the default Rootless Network     *"
            echo "*    Cmd is configured to use 'pasta' we will create or modify the        *"
            echo "*    ~/.config/containers/containers.conf file to use 'slirp4netns'       *"
            echo "*    as the default_rootless_network_cmd.                                 *"
            echo "*                                                                         *"
            echo "********************************* WARNING *********************************"
            echo ""
        fi

        read -p "Continue installing under Podman (type YES)? " PODMAN_RESPONSE
        if [[ "$PODMAN_RESPONSE" != "YES" ]]; then
            echo ""
            echo "Aborting install."
            exit 1
        fi

        # set setup_data context to allow containers to write to the directory
        #
        selinux_status=$(sestatus 2>/dev/null | grep "SELinux status:" | awk '{print $3}')
        if [ ! -z "${selinux_status}" ]; then
            if [ $selinux_status = "enabled" ]; then
                if [ -d setup_data ] ; then
                    echo "Set SELinux context of setup_data directory"
                    chcon -v -Rt svirt_sandbox_file_t setup_data
                fi
            fi
        fi

        # change unprivileged_port_start to allow non-root process to bind to ports
        #   80 and 443 (requires sudo)
        # enable Linger for non-root user
        # configure 'slirp4netns' as the default_rootless_network_cmd
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
                loginctl enable-linger $USER
            fi

            containers_conf=~/.config/containers/containers.conf
            podman_version=$(podman version -f '{{.Client.Version}}' 2>/dev/null)
            podman_major_version=$(podman version -f '{{index (split .Client.Version ".") 0}}' 2>/dev/null)
            if [ ! -z "${podman_major_version}" ]; then
                if [ $podman_major_version -gt 4 ]; then
                    t_podman_network=$(podman info --format='{{.Host.RootlessNetworkCmd}}' 2>/dev/null)
                    echo "Podman rootless network cmd : $t_podman_network"
                    if [ ! "$t_podman_network" == "slirp4netns" ]; then
                        echo "WARNING: must use slirp4netns as rootlessNetworkCmd"
                        if [ -f ${containers_conf} ]; then
                            # Save a copy of the original containers.conf file
                            cp -f -p -v ${containers_conf} ${containers_conf}.bak

                            # Remove any previously configured default_rootless_network_cmd entries:
                            sed -i '/^default_rootless_network_cmd/d' ${containers_conf}

                            diff -c ${containers_conf}.bak ${containers_conf}

                            # Make sure we have a [network] stanza in the containers.conf file
                            t_network=$(grep "^\[network\]" ${containers_conf} | wc -l)
                            if [ $t_network -eq 0 ]; then
                                echo "[network]" >> ${containers_conf}
                            fi

                            # Configure slirp4netns as default_rootless_network_cmd
                            t_count=$(grep "^#default_rootless_network_cmd =" ${containers_conf} | wc -l)
                            if [ $t_count -ge 1 ]; then
                                sed -i '/^#default_rootless_network_cmd/a default_rootless_network_cmd = "slirp4netns"' ${containers_conf}
                            else
                                sed -i '/^\[network\]/a default_rootless_network_cmd = "slirp4netns"' ${containers_conf}
                            fi

                            diff -c ${containers_conf}.bak ${containers_conf}
                        else
                            # Create the containers.conf file with [network] stanza
                            echo "[network]" > ${containers_conf}
                            sed -i '/^\[network\]/a default_rootless_network_cmd = "slirp4netns"' ${containers_conf}
                        fi

                        t_verify_network=$(podman info --format='{{.Host.RootlessNetworkCmd}}' 2>/dev/null)
                        echo "Podman rootless network cmd : $t_verify_network"
                        if [ ! "$t_verify_network" == "slirp4netns" ]; then
                            echo ""
                            echo "ERROR: must use slirp4netns as rootlessNetworkCmd, exit"
                            echo ""
                            exit
                        fi
                    fi
                else
                    echo "*** RootlessNetworkCmd not supported in Podman Version $podman_version"
                fi
            fi
        fi
    fi
fi

[ "$SANDFLY_AUTO" = "YES" ] && cat << EOF
This will be a fully-automated setup.

Hostname: $SANDFLY_SETUP_AUTO_HOSTNAME
Sandfly Management Image: $SANDFLY_MGMT_DOCKER_IMAGE

EOF

docker network create sandfly-net 2>/dev/null
docker rm sandfly-server-mgmt 2>/dev/null

# Load images if offline bundle is present and not already loaded
./setup_scripts/load_images.sh
if [ "$?" -ne 0 ]; then
  echo "Error loading container images."
  exit 1
fi

# The first time we start Postgres, we need to assign a superuser password.
POSTGRES_ADMIN_PASSWORD=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c40)
echo "$POSTGRES_ADMIN_PASSWORD" > $SETUP_DATA_DIR/postgres.admin.password.txt
echo "Starting Postgres database."
../start_scripts/start_postgres.sh
if [[ $? -ne 0 ]]
then
  echo "Error starting Postgres container. Aborting install."
  exit 1
else
  sleep 5
fi

./setup_scripts/setup_server.sh
if [[ $? -ne 0 ]]
then
  echo "Server setup did not run. Aborting install."
  exit 1
fi

./setup_scripts/setup_keys.sh
if [[ $? -ne 0 ]]
then
  echo "Server and node key setup did not run. Aborting install."
  exit 1
fi

# Need to provide the API server hostname, which was written to a file in
# setup_server.sh, to generate the SSL cert.
SSL_SERVER_HOSTNAME=$(cat ./setup_data/api.server.hostname.txt)
export SSL_SERVER_HOSTNAME

./setup_scripts/setup_ssl.sh
if [[ $? -ne 0 ]]
then
  echo "SSL setup did not run. Aborting install."
  exit 1
fi

if [ -z "$SANDFLY_AUTO" ]; then
  cat << EOF

******************************************************************************
Make Signed SSL Key?

If the Sandfly server is able to be seen on the Internet, we can generate a
signed key using EFF's Let's Encrypt Bot. Answer below if you'd like to do
this.
******************************************************************************

EOF
  read -p "Generate signed SSL keys (type YES)? " RESPONSE
  if [[ "$RESPONSE" = "YES" ]]
  then
      echo "Starting key signing script"
      ./setup_scripts/setup_ssl_signed.sh
  fi
elif [ ! -z "$SSL_FQDN" ]; then
  # Attempt an automated Let's Encrypt setup. The existing SSL_FQDN (and
  # SSL_EMAIL) environment variables will flow through, causing the script
  # to run in non-interactive mode.
  echo "Starting automated key signing script"
  ./setup_scripts/setup_ssl_signed.sh
fi # if auto

./setup_scripts/setup_config_json.sh
if [[ $? -ne 0 ]]
then
  echo "Server and node config JSON could not be generated. Aborting install."
  exit 1
fi


cat << EOF

******************************************************************************
Setup Complete!

Your setup is complete. Please see below for the path to the admin password to
login.

You will need to go to $(realpath $PWD/../start_scripts) and run the following to start the
server:

./start_sandfly.sh

Your randomly generated password for the admin account is located under:

$PWD/setup_data/admin.password.txt
******************************************************************************

EOF
