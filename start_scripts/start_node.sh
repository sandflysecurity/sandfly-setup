#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2023 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SETUP_DATA=../setup/setup_data
VERSION=${SANDFLY_VERSION:-$(cat ../VERSION)}
IMAGE_BASE=${SANDFLY_IMAGE_BASE:-quay.io/sandfly}

# Use valid (#m or #g) env variable, otherwise the Sandfly default.
if  [[ "${SANDFLY_LOG_MAX_SIZE}" =~ ^[1-9][0-9]*[m|g]$ ]]; then
  LOG_MAX_SIZE=${SANDFLY_LOG_MAX_SIZE}
else
  LOG_MAX_SIZE="100m"
fi

# Remove old scripts
../setup/clean_scripts.sh

if [ -f "/snap/bin/docker" ]; then
    echo ""
    echo "****************************** ERROR ******************************"
    echo "*                                                                 *"
    echo "* A version of Docker appears to be installed via Snap.           *"
    echo "*                                                                 *"
    echo "* Sandfly is only compatible with the apt version of Docker.      *"
    echo "* Having both versions installed will conflict with Sandfly.      *"
    echo "* Please remove the snap version before starting a node.          *"
    echo "*                                                                 *"
    echo "****************************** ERROR ******************************"
    echo ""
    exit 1
fi

if [ ! -f $SETUP_DATA/config.node.json ]; then
    echo
    echo "***************************** ERROR *******************************"
    echo
    echo "The node config data ($SETUP_DATA/config.node.json) is not present on the"
    echo "node. This file must be present for the scanning nodes to start. Please copy"
    echo "this file from the server setup_data directory and try again."
    echo
    echo "Exiting node start."
    echo "***************************** ERROR *******************************"
    echo
    exit 1
fi

# See if we can run Docker
which docker >/dev/null 2>&1 || { echo "Unable to locate docker binary; please install Docker."; exit 1; }
docker version >/dev/null 2>&1 || { echo "This script must be run as root or as a user with access to the Docker daemon."; exit 1; }

# Load images if offline bundle is present and not already loaded
../setup/setup_scripts/load_images.sh
if [ "$?" -ne 0 ]; then
  echo "Error loading container images."
  exit 1
fi

# Populate env variables.
CONFIG_JSON=$(cat $SETUP_DATA/config.node.json)
export CONFIG_JSON

# If the node is running on the server (judging by the presence of the server
# config file), use internal Docker network to communicate with the server.
# We will pass in an environment variable to the startup script that will
# ignore the normal hostname configuration.
EXTRA_PARAMS=""
if [ -f $SETUP_DATA/config.server.json ]; then
  echo
  echo "** Note: config.server.json file present; assuming Node is running on"
  echo "         same host as the Sandfly Server."
  echo

  EXTRA_PARAMS="--network sandfly-net -e LOCAL_SERVER=true"
fi

docker run -v /dev/urandom:/dev/random:ro \
--label sandfly-node \
-e CONFIG_JSON \
--disable-content-trust \
--restart=always \
--security-opt="no-new-privileges:true" \
--log-driver json-file \
--log-opt max-size=${LOG_MAX_SIZE} \
--log-opt max-file=5 \
--user sandfly:sandfly \
$EXTRA_PARAMS \
-d $IMAGE_BASE/sandfly${IMAGE_SUFFIX}:"$VERSION" /opt/sandfly/start_node.sh

podman_command=$(command -v podman)
if [ ! -z "${podman_command}" ]; then
    docker_engine=$(docker version | grep "^Client:" | awk '{print tolower($2)}')
    if [ "$docker_engine" != "docker" ]; then
        t_cgroup_mgr=$(podman info --format='{{.Host.CgroupManager}}' 2>/dev/null)
        echo "*** Podman cgroup manager : $t_cgroup_mgr"

        for node in $(docker container ls --quiet --filter "label=sandfly-node"); do
            node_name=$(docker inspect $node --format "{{.Name}}")
            CONTAINER_FILE=sandfly-node-$node_name.container
            if [[ ! -f $CONTAINER_FILE ]]; then
                echo "*** Generate $CONTAINER_FILE for $node_name"
                t_CONFIG_JSON=$(echo $CONFIG_JSON)
                echo "[Container]" > $CONTAINER_FILE
                echo "ContainerName=$node_name" >> $CONTAINER_FILE
                echo "Environment=CONFIG_JSON='${t_CONFIG_JSON}'" >> $CONTAINER_FILE
                echo "Exec=/opt/sandfly/start_node.sh" >> $CONTAINER_FILE
                echo "Group=sandfly" >> $CONTAINER_FILE
                echo "Image=$IMAGE_BASE/sandfly${IMAGE_SUFFIX}:$VERSION" >> $CONTAINER_FILE
                echo "Label=sandfly-node=" >> $CONTAINER_FILE
                echo "LogDriver=json-file" >> $CONTAINER_FILE
                if [ "$t_cgroup_mgr" != "systemd" ]; then
                    echo "PodmanArgs=--cgroups=enabled --disable-content-trust --log-opt 'max-size=${LOG_MAX_SIZE}' --log-opt 'max-file=5'" >> $CONTAINER_FILE
                else
                    echo "PodmanArgs=--disable-content-trust --log-opt 'max-size=${LOG_MAX_SIZE}' --log-opt 'max-file=5'" >> $CONTAINER_FILE
                fi
                echo "User=sandfly" >> $CONTAINER_FILE
                echo "Volume=/dev/urandom:/dev/random:ro" >> $CONTAINER_FILE
                echo "" >> $CONTAINER_FILE
                if [ -f sandfly-server.container ]; then
                    echo "[Unit]" >> $CONTAINER_FILE
                    echo "Requires=sandfly-server.service" >> $CONTAINER_FILE
                    echo "After=sandfly-server.service" >> $CONTAINER_FILE
                fi
                echo "" >> $CONTAINER_FILE
                echo "[Service]" >> $CONTAINER_FILE
                echo "Restart=always" >> $CONTAINER_FILE
                echo "" >> $CONTAINER_FILE
                echo "[Install]" >> $CONTAINER_FILE
                echo "WantedBy=default.target" >> $CONTAINER_FILE

                SYSTEM_CTL="systemctl --user"
                TARGET_DIR=~/.config/containers/systemd
                if [ $(id -u) -eq 0 ]; then
                    SYSTEM_CTL="systemctl"
                    TARGET_DIR=/etc/containers/systemd
                    echo "*** Running as rootful user  : [$USER] : [$SYSTEM_CTL] : [$TARGET_DIR]"
                else
                    echo "*** Running as rootless user : [$USER] : [$SYSTEM_CTL] : [$TARGET_DIR]"
                    linger_status=$(loginctl show-user $USER | grep ^Linger | awk -F= '{print $2}')
                    echo "*** Linger Status: [$linger_status]"
                    if [ "$linger_status" = "no" ]; then
                        echo "*** Enable Linger for user $USER"
                        loginctl enable-linger $USER
                    fi
                fi
                if [ ! -d $TARGET_DIR ]; then
                    mkdir -p $TARGET_DIR
                fi
                echo "*** Copy $CONTAINER_FILE to $TARGET_DIR"
                cp $CONTAINER_FILE $TARGET_DIR
                echo "*** $SYSTEM_CTL daemon-reload"
                $SYSTEM_CTL daemon-reload
            fi
        done
    fi
fi

exit $?
