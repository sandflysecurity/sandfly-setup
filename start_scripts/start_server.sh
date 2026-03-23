#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SETUP_DATA=../setup/setup_data
VERSION=${SANDFLY_VERSION:-$(cat ../VERSION)}
IMAGE_BASE=${SANDFLY_IMAGE_BASE:-quay.io/sandfly}

# External ports to publish. Override to use non-standard ports, e.g.:
#   SANDFLY_HTTPS_PORT=8443 SANDFLY_HTTP_PORT=8080 ./start_server.sh
SANDFLY_HTTP_PORT=${SANDFLY_HTTP_PORT:-80}
SANDFLY_HTTPS_PORT=${SANDFLY_HTTPS_PORT:-443}

# Use valid (#m or #g) env variable, otherwise the Sandfly default.
if  [[ "${SANDFLY_LOG_MAX_SIZE}" =~ ^[1-9][0-9]*[m|g]$ ]]; then
  LOG_MAX_SIZE=${SANDFLY_LOG_MAX_SIZE}
else
  LOG_MAX_SIZE="100m"
fi

# Remove old scripts
../setup/setup_scripts/clean_scripts.sh

if [ -e $SETUP_DATA/allinone ]; then
    IGNORE_NODE_DATA_WARNING=YES
fi

# Set CONTAINERMGR variable
. ../setup/setup_scripts/container_command.sh
if [ $? -ne 0 ]; then
    # Failed to find container runtime. The container_command script will
    # have printed an error.
    exit 1
fi

if [ -n "$($CONTAINERMGR ps -q -f name=^/sandfly-server$)" ]; then
  echo "Container sandfly-server is already running." >&2
  exit 1
fi

# Auto-convert old JSON config to env format if needed.
if [ -f $SETUP_DATA/config.server.json ] && \
   [ ! -f $SETUP_DATA/config.server.env ]; then
    echo "Converting config.server.json to config.server.env..."
    CERTOUT_ARGS=""
    CERT_DIR=$SETUP_DATA/server_ssl_cert
    if [ ! -f $CERT_DIR/cert.pem ] || [ ! -f $CERT_DIR/privatekey.pem ]; then
        mkdir -p "$CERT_DIR"
        CERTOUT_ARGS="-certout $CERT_DIR/cert.pem -keyout $CERT_DIR/privatekey.pem"
    fi
    ../setup/setup_scripts/setuphelper convertserver \
        -in "$SETUP_DATA/config.server.json" \
        -out "$SETUP_DATA/config.server.env" \
        $CERTOUT_ARGS
    if [ $? -ne 0 ]; then
        echo "Error converting server configuration."
        exit 1
    fi
    mv "$SETUP_DATA/config.server.json" \
       "$SETUP_DATA/config.server.json.retired"
fi

if [ ! -f ../setup/setup_data/config.server.env ]; then
    echo ""
    echo "********************************** ERROR **********************************"
    echo "*                                                                         *"
    echo "* Sandfly does not appear to be configured. Please use install.sh to      *"
    echo "* perform a new installation of Sandfly on this host.                     *"
    echo "*                                                                         *"
    echo "********************************** ERROR **********************************"
    echo ""
    exit 1
fi

if [ -f $SETUP_DATA/config.node.env -a "$IGNORE_NODE_DATA_WARNING" != "YES" ]; then
    echo ""
    echo "********************************* WARNING *********************************"
    echo "*                                                                         *"
    echo "* The node config data file at:                                           *"
    printf "*     %-67s *\n" "$SETUP_DATA/config.node.env"
    echo "* is present on the server.                                               *"
    echo "*                                                                         *"
    echo "* This file must be deleted from the server to fully protect the SSH keys *"
    echo "* stored in the database. It should only be on the nodes.                 *"
    echo "*                                                                         *"
    echo "********************************* WARNING *********************************"
    echo ""
    echo "Are you sure you want to start the server with the node config data present?"
    read -p "Type YES if you're sure. [NO]: " RESPONSE
    if [ "$RESPONSE" != "YES" ]; then
        echo "Halting server start."
        exit 1
    fi
fi

# Load images if offline bundle is present and not already loaded
../setup/setup_scripts/load_images.sh
if [ "$?" -ne 0 ]; then
  echo "Error loading container images."
  exit 1
fi

# Old versions of Sandfly may have left behind a temporary volume for the
# old rabbit container. Clean it up if present.
$CONTAINERMGR volume rm sandfly-rabbitmq-tmp-vol 2>/dev/null

# Set volume mount flags based on SELinux status
VOLUME_MOUNT_FLAGS="ro"
selinux_status=$(sestatus 2>/dev/null | grep "SELinux status:" | awk '{print $3}')
if [ ! -z "${selinux_status}" ]; then
    if [ $selinux_status = "enabled" ]; then
        VOLUME_MOUNT_FLAGS="ro,z"
    fi
fi

# Check for user-managed TLS certificates
TLS_VOLUME_MOUNT=""
SETUP_DATA_ABS=$(cd $SETUP_DATA && pwd)
if [ -f $SETUP_DATA/server_ssl_cert/cert.pem ] && \
   [ -f $SETUP_DATA/server_ssl_cert/privatekey.pem ]; then
    echo "Using user-managed TLS certificates from server_ssl_cert directory."
    TLS_VOLUME_MOUNT="-v $SETUP_DATA_ABS/server_ssl_cert:/etc/sandflytls:$VOLUME_MOUNT_FLAGS"
fi

HTTPS_PORT_REDIRECT_ARG=""
if [ "$SANDFLY_HTTPS_PORT" != "443" ]; then
    HTTPS_PORT_REDIRECT_ARG="-e SF_HTTP_REDIRECT_PORT=$SANDFLY_HTTPS_PORT"
fi

$CONTAINERMGR network create sandfly-net 2>/dev/null
$CONTAINERMGR rm sandfly-server 2>/dev/null

$CONTAINERMGR run -v /dev/urandom:/dev/random:ro \
$TLS_VOLUME_MOUNT \
--env-file "${SETUP_DATA}/config.server.env" \
${HTTPS_PORT_REDIRECT_ARG} \
--disable-content-trust \
--restart=always \
--security-opt="no-new-privileges:true" \
--network sandfly-net \
--name sandfly-server \
--label sandfly-server \
--user sandfly:sandfly \
--publish ${SANDFLY_HTTPS_PORT}:8443 \
--publish ${SANDFLY_HTTP_PORT}:8000 \
--log-driver json-file \
--log-opt max-size=${LOG_MAX_SIZE} \
--log-opt max-file=5 \
-d $IMAGE_BASE/sandfly${IMAGE_SUFFIX}:"$VERSION" /opt/sandfly/start_api.sh

if [ "$CONTAINERMGR" = "podman" ]; then
    t_cgroup_mgr=$(podman info --format='{{.Host.CgroupManager}}' 2>/dev/null)
    echo "*** Podman cgroup manager : $t_cgroup_mgr"

    CONTAINER_FILE=sandfly-server.container
    if [[ -f $CONTAINER_FILE ]]; then
        rm -f $CONTAINER_FILE
    fi
    echo "*** Generate $CONTAINER_FILE for sandfly-server"
    SETUP_DATA_ABS=$(realpath "$SETUP_DATA")
    echo "[Container]" > $CONTAINER_FILE
    echo "ContainerName=sandfly-server" >> $CONTAINER_FILE
    echo "EnvironmentFile=${SETUP_DATA_ABS}/config.server.env" >> $CONTAINER_FILE
    echo "Exec=/opt/sandfly/start_api.sh" >> $CONTAINER_FILE
    echo "Group=sandfly" >> $CONTAINER_FILE
    echo "Image=$IMAGE_BASE/sandfly${IMAGE_SUFFIX}:$VERSION" >> $CONTAINER_FILE
    echo "Label=sandfly-server=" >> $CONTAINER_FILE
    echo "LogDriver=json-file" >> $CONTAINER_FILE
    echo "Network=sandfly-net" >> $CONTAINER_FILE
    if [ "$t_cgroup_mgr" != "systemd" ]; then
        echo "PodmanArgs=--cgroups=enabled --disable-content-trust --log-opt 'max-size=${LOG_MAX_SIZE}' --log-opt 'max-file=5'" >> $CONTAINER_FILE
    else
        echo "PodmanArgs=--disable-content-trust --log-opt 'max-size=${LOG_MAX_SIZE}' --log-opt 'max-file=5'" >> $CONTAINER_FILE
    fi
    echo "PublishPort=${SANDFLY_HTTPS_PORT}:8443" >> $CONTAINER_FILE
    echo "PublishPort=${SANDFLY_HTTP_PORT}:8000" >> $CONTAINER_FILE
    if [ "$SANDFLY_HTTPS_PORT" != "443" ]; then
        echo "Environment=SF_HTTP_REDIRECT_PORT=$SANDFLY_HTTPS_PORT" >> $CONTAINER_FILE
    fi
    echo "User=sandfly" >> $CONTAINER_FILE
    echo "Volume=/dev/urandom:/dev/random:ro" >> $CONTAINER_FILE
    if [ -f $SETUP_DATA/server_ssl_cert/cert.pem ] && \
       [ -f $SETUP_DATA/server_ssl_cert/privatekey.pem ]; then
        echo "Volume=$SETUP_DATA_ABS/server_ssl_cert:/etc/sandflytls:$VOLUME_MOUNT_FLAGS" >> $CONTAINER_FILE
    fi
    echo "" >> $CONTAINER_FILE
    echo "[Unit]" >> $CONTAINER_FILE
    echo "Requires=sandfly-postgres.service" >> $CONTAINER_FILE
    echo "After=sandfly-postgres.service" >> $CONTAINER_FILE
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

exit $?
