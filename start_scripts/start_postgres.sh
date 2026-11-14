#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

IMAGE_BASE=${POSTGRES_IMAGE_BASE:-docker.io/library}

LOG_MAX_SIZE="20m"

# Set CONTAINERMGR variable
. ../setup/setup_scripts/container_command.sh
if [ $? -ne 0 ]; then
    # Failed to find container runtime. The container_command script will
    # have printed an error.
    exit 1
fi

if [ -n "$($CONTAINERMGR ps -q -f name=^/sandfly-postgres$)" ]; then
  echo "Container sandfly-postgres is already running." >&2
  exit 1
fi

# Postgres versions. Other scripts (load_images.sh, upgrade_postgres.sh,
# generate_compose.sh, etc.) read these values from this file.
PG14_VERSION=14.25
PG18_VERSION=18.7

# Determine which volume to use. New installs use sandfly-pg-db-vol, which
# isn't tied to a Postgres version since upgrades happen in place. Older
# installs use a legacy volume named for the Postgres version they were
# installed with: sandfly-pg18-db-vol, or sandfly-pg14-db-vol. Note that a
# pg14 volume may hold Postgres 18 data if it was upgraded in place by
# upgrade_postgres.sh. The Postgres version is determined from the volume's
# contents below, not from its name.
NEW_INSTALL=false
if $CONTAINERMGR volume inspect sandfly-pg-db-vol >/dev/null 2>&1; then
    VOLNAME=sandfly-pg-db-vol
elif $CONTAINERMGR volume inspect sandfly-pg18-db-vol >/dev/null 2>&1; then
    VOLNAME=sandfly-pg18-db-vol
elif $CONTAINERMGR volume inspect sandfly-pg14-db-vol >/dev/null 2>&1; then
    VOLNAME=sandfly-pg14-db-vol
else
    VOLNAME=sandfly-pg-db-vol
    NEW_INSTALL=true
fi

# Load images if offline bundle is present and not already loaded
../setup/setup_scripts/load_images.sh
if [ "$?" -ne 0 ]; then
  echo "Error loading container images."
  exit 1
fi

# Inspect the contents of an existing volume to determine which Postgres
# version and directory layout it holds. Prints one of: 14, 18, empty,
# upgrading, or unknown.
#
# Postgres 14 data lives at the root of the volume, which is mounted at
# /var/lib/postgresql/data. Postgres 18 data lives in 18/docker inside the
# volume, which is mounted at /var/lib/postgresql. This is the layout the
# official Postgres 18+ images expect, and it allows future major version
# upgrades to be done in place with "pg_upgrade --link".
#
# Earlier versions of this script mounted sandfly-pg18-db-vol at
# /var/lib/postgresql/data like Postgres 14. If Postgres 18 data is found at
# the root of the volume, it is moved into 18/docker. The move is a handful
# of renames within the volume, so it is instant regardless of database size,
# and resumes safely if interrupted.
probe_volume() {
    local image=$1
    $CONTAINERMGR run --rm --network none \
        --mount type=volume,source=${VOLNAME},target=/sfvol \
        --entrypoint sh "$image" -c '
set -e
V=/sfvol
S=$V/.sandfly-relayout
if [ -d "$S" ] || [ "$(cat $V/PG_VERSION 2>/dev/null)" = "18" ]; then
    echo "*** Moving Postgres 18 data to 18/docker within the volume" >&2
    mkdir -p "$S"
    chown --reference="$V" "$S"
    chmod 700 "$S"
    find "$V" -mindepth 1 -maxdepth 1 ! -name .sandfly-relayout ! -name 18 \
        -exec mv -t "$S" {} +
    mkdir -p "$V/18"
    chown --reference="$V" "$V/18"
    mv -T "$S" "$V/18/docker"
fi
if [ -e "$V/14" ] || [ -e "$V/.sandfly-upgrade-stage" ] || \
        [ -e "$V/18/.sandfly-upgrade-done" ]; then
    echo upgrading
elif [ -s "$V/18/docker/PG_VERSION" ]; then
    cat "$V/18/docker/PG_VERSION"
elif [ -s "$V/PG_VERSION" ]; then
    cat "$V/PG_VERSION"
elif [ -z "$(ls -A "$V")" ]; then
    echo empty
else
    echo unknown
fi'
}

if [ "$NEW_INSTALL" = "true" ]; then
    DATA_VERSION=18
elif [ "$VOLNAME" = "sandfly-pg14-db-vol" ]; then
    DATA_VERSION=$(probe_volume ${IMAGE_BASE}/postgres:${PG14_VERSION})
    # An empty pg14 volume gets initialized as Postgres 14.
    [ "$DATA_VERSION" = "empty" ] && DATA_VERSION=14
else
    DATA_VERSION=$(probe_volume ${IMAGE_BASE}/postgres:${PG18_VERSION})
    # An empty volume gets initialized as Postgres 18.
    [ "$DATA_VERSION" = "empty" ] && DATA_VERSION=18
fi

case "$DATA_VERSION" in
    18)
        VERSION=$PG18_VERSION
        MOUNT_TARGET=/var/lib/postgresql
        PG_DATA_DIR=/var/lib/postgresql/18/docker
        ;;
    14)
        VERSION=$PG14_VERSION
        MOUNT_TARGET=/var/lib/postgresql/data
        PG_DATA_DIR=/var/lib/postgresql/data
        echo ""
        echo "*** NOTE: Sandfly is using Postgres 14. Please upgrade to Postgres 18"
        echo "*** with setup/util_scripts/upgrade_postgres.sh at your convenience."
        echo ""
        ;;
    upgrading)
        echo ""
        echo "********************************** ERROR **********************************"
        echo "*                                                                         *"
        echo "* A Postgres upgrade was started on the ${VOLNAME} volume        *"
        echo "* but did not finish. Please run upgrade_postgres.sh in the               *"
        echo "* setup/util_scripts directory again to complete it.                      *"
        echo "*                                                                         *"
        echo "********************************** ERROR **********************************"
        echo ""
        exit 1
        ;;
    *)
        echo "ERROR: Unable to determine the Postgres version of the data in the" >&2
        echo "${VOLNAME} volume (got: '${DATA_VERSION}')." >&2
        exit 1
        ;;
esac

# After the first time Postgres starts, the admin password will be set in the
# database in the Docker volume we use, and setting the password through the
# docker run command will have no effect (e.g. it doesn't try to change it if
# a database already exists). If this is an initial install, the password we
# want to use should be in setup_data courtesy of the setuphelper tool.
POSTGRES_ADMIN_PASSWORD="unknown"
if [ "$NEW_INSTALL" = "true" ]; then
    if [ -f ../setup/setup_data/config.server.env ]; then
        POSTGRES_ADMIN_PASSWORD=$(grep '^SF_DB_ADMIN_CONNSTR=' \
            ../setup/setup_data/config.server.env | \
            sed 's/.*password=\([^ ]*\).*/\1/')
    fi
fi

# Pool sizes are stored in the database config table and managed through
# the API. Use defaults here for Postgres max_connections calculation.
POOL_SIZE=50
POOL_SIZE_NODES=30
RESULT_WORKERS=20

# If necessary, we adjust POOL_SIZE_NODES to be a minimum of 10 more than
# RESULT_WORKERS to make sure we have enough connections for when the server
# code does the same thing.
if [ $(($POOL_SIZE_NODES-$RESULT_WORKERS)) -lt 10 ]; then
    echo "INFO: Adjusting POOL_SIZE_NODES to ensure 10 extra connections"
    POOL_SIZE_NODES=$((RESULT_WORKERS+10))
fi

#############################################################################
### POSTGRES TUNING CALCULATIONS ############################################
### Roughly following 'pgtune' project calculations #########################
#############################################################################

cpu_count=$(grep -c '^processor' /proc/cpuinfo)
ram_total=$(free -k | grep Mem | awk '{print $2}')
max_connections=$(($POOL_SIZE+$POOL_SIZE_NODES))

# We will calculate based on 70% of system RAM for postgres, leaving
# 30% for Sandfly, etc.
ram_postgres=$(( $ram_total / 10 * 7 ))

shared_buffers=$(( $ram_postgres / 4 ))
effective_cache_size=$(( $ram_postgres / 4 * 3 ))
maintenance_work_mem=$(( $ram_postgres / 16 ))
wal_buffer=$(( $shared_buffers * 3 / 100)) # 3% of shared_buffers
if [[ $wal_buffer -gt 14336 ]]; then
    # If at or above 14MB, set to 16MB
    wal_buffer=16384
fi
if [[ $wal_buffer -lt 32 ]]; then
    # Minimum 32kB
    wal_buffer=32
fi
if [[ $maintenance_work_mem -gt 2097152 ]]; then
    # 2GB cap for maintenance_work_mem
    maintenance_work_mem=2097152
fi
if [[ $maintenance_work_mem -lt 1048576 ]]; then
    # 1GB minimum for maintenance_work_mem
    maintenance_work_mem=1048576
fi
parallel_workers=$(( $cpu_count / 2))
if [[ $parallel_workers -lt 1 ]]; then
    parallel_workers=1
fi
if [[ $parallel_workers -gt 4 ]]; then
    # cap parallel_workers (per task) at 4
    parallel_workers=4
fi
# work_mem is sized for a fixed number of connections rather than
# max_connections. Most of the interactive pool sits idle or runs short
# queries, so growing the pool shouldn't shrink the memory available to the
# queries that do sort and hash large result sets.
work_mem_connections=50
work_mem=$(( ($ram_postgres - $shared_buffers) / ($work_mem_connections * 3) / $parallel_workers ))
if [[ $work_mem -lt 64 ]]; then
    # minimum of 64kB for work_mem
    work_mem=64
fi

# Allow override of max_wal_size via environment variable
max_wal_size=${MAX_WAL_SIZE:-16GB}

echo ""
echo "Based on $cpu_count CPUs and ${ram_total}kB total RAM, we will start"
echo "Postgres with the following settings:"
echo ""
echo "max_connections                  = $(($max_connections+10))"
echo "shared_buffers                   = ${shared_buffers}kB"
echo "effective_cache_size             = ${effective_cache_size}kB"
echo "maintenance_work_mem             = ${maintenance_work_mem}kB"
echo "checkpoint_completion_target     = 0.9"
echo "wal_buffers                      = ${wal_buffer}kB"
echo "default_statistics_target        = 100"
echo "random_page_cost                 = 2"
echo "effective_io_concurrency         = 100"
echo "work_mem                         = ${work_mem}kB"
echo "min_wal_size                     = 2GB"
echo "max_wal_size                     = $max_wal_size"
echo "max_worker_processes             = $cpu_count"
echo "max_parallel_workers             = $cpu_count"
echo "max_parallel_workers_per_gather  = $parallel_workers"
echo "max_parallel_maintenance_workers = $parallel_workers"
echo ""

#############################################################################
### END OF POSTGRES TUNING CALCULATIONS #####################################
#############################################################################

# If the volume already exists (e.g. this isn't the first startup during
# initial installation), print a warning if the volume is on a disk that is
# more than 85% full.
$CONTAINERMGR inspect $VOLNAME >/dev/null 2>/dev/null && \
diskuse=$(df --output=pcent \
    $($CONTAINERMGR inspect $VOLNAME -f '{{json .Mountpoint}}' | \
    tr -d \" ) | grep -v "Use%"|tr -d " %") && \
if [[ $diskuse -gt 85 ]]; then
    echo ""
    echo "********************************* WARNING ***********************************"
    echo "*                                                                           *"
    echo "* The disk holding the Sandfly Postgres Docker volume, ${VOLNAME}, *"
    echo "* is using more than 85% of available space. If the disk fills during       *"
    echo "* Sandfly operation, it will become impossible to log in, delete results,   *"
    echo "* etc.                                                                      *"
    echo "*                                                                           *"
    echo "* Please free up disk space, or increase the size of the disk, before       *"
    echo "* starting Sandfly.                                                         *"
    echo "*                                                                           *"
    echo "* If you wish to continue anyway with low disk space, enter YES at the      *"
    echo "* prompt.                                                                   *"
    echo "********************************* WARNING ***********************************"
    echo ""
    echo "The disk is currently ${diskuse}% full."
    echo "Do you wish to start the database despite having low free disk space?"
    read -p "Type YES if you're sure. [NO]: " RESPONSE
    if [ "$RESPONSE" != "YES" ]; then
        echo "Halting database start."
        exit 1
    fi
fi

../setup/setup_scripts/create_sandfly_net.sh
if [ "$?" -ne 0 ]; then
  echo "Error creating sandfly-net."
  exit 1
fi

# -v also removes any anonymous volumes attached to the old container. (Older
# versions of this script left an anonymous volume behind on every start.)
# Named volumes, such as our data volume, are never removed by -v.
$CONTAINERMGR rm -v sandfly-postgres 2>/dev/null

$CONTAINERMGR run \
--mount type=volume,source=${VOLNAME},target=${MOUNT_TARGET} \
-d \
-e POSTGRES_PASSWORD="$POSTGRES_ADMIN_PASSWORD" \
-e PGDATA=${PG_DATA_DIR} \
--shm-size=${ram_total}k \
--restart=always \
--security-opt="no-new-privileges:true" \
--network sandfly-net \
--name sandfly-postgres \
--label sandfly-postgres \
--log-driver json-file \
--log-opt max-size=${LOG_MAX_SIZE} \
--log-opt max-file=5 \
-t \
${IMAGE_BASE}/postgres:${VERSION} \
-c max_connections=$(($max_connections+10)) \
-c shared_buffers=${shared_buffers}kB \
-c effective_cache_size=${effective_cache_size}kB \
-c maintenance_work_mem=${maintenance_work_mem}kB \
-c checkpoint_completion_target=0.9 \
-c wal_buffers=${wal_buffer}kB \
-c default_statistics_target=100 \
-c random_page_cost=2 \
-c effective_io_concurrency=100 \
-c work_mem=${work_mem}kB \
-c min_wal_size=2GB \
-c max_wal_size=$max_wal_size \
-c max_worker_processes=$cpu_count \
-c max_parallel_workers_per_gather=$parallel_workers \
-c max_parallel_workers=$cpu_count \
-c max_parallel_maintenance_workers=$parallel_workers

# Check the running state of the postgres container.
pgresult=$($CONTAINERMGR inspect --format="{{.State.Running}}" sandfly-postgres 2> /dev/null)
if [ "${pgresult}z" != "truez" ]; then
  exit 1
fi

if [ "$CONTAINERMGR" = "podman" ]; then
    t_cgroup_mgr=$(podman info --format='{{.Host.CgroupManager}}' 2>/dev/null)
    echo "*** Podman cgroup manager : $t_cgroup_mgr"

    CONTAINER_FILE=sandfly-postgres.container
    if [[ -f $CONTAINER_FILE ]]; then
        rm -f $CONTAINER_FILE
    fi
    echo "*** Generate $CONTAINER_FILE for sandfly-postgres"
    echo "[Container]" > $CONTAINER_FILE
    echo "ContainerName=sandfly-postgres" >> $CONTAINER_FILE
    echo "Environment=POSTGRES_PASSWORD=${POSTGRES_ADMIN_PASSWORD} PGDATA=${PG_DATA_DIR}" >> $CONTAINER_FILE
    echo "Exec=-c max_connections=$(($max_connections+10)) \
        -c shared_buffers=${shared_buffers}kB \
        -c effective_cache_size=${effective_cache_size}kB \
        -c maintenance_work_mem=${maintenance_work_mem}kB \
        -c checkpoint_completion_target=0.9 \
        -c wal_buffers=${wal_buffer}kB \
        -c default_statistics_target=100 \
        -c random_page_cost=2 \
        -c effective_io_concurrency=100 \
        -c work_mem=${work_mem}kB \
        -c min_wal_size=2GB \
        -c max_wal_size=$max_wal_size \
        -c max_worker_processes=$cpu_count \
        -c max_parallel_workers_per_gather=$parallel_workers \
        -c max_parallel_workers=$cpu_count \
        -c max_parallel_maintenance_workers=$parallel_workers" >> $CONTAINER_FILE
    echo "Image=$IMAGE_BASE/postgres:$VERSION" >> $CONTAINER_FILE
    echo "Label=sandfly-postgres=" >> $CONTAINER_FILE
    echo "LogDriver=json-file" >> $CONTAINER_FILE
    echo "Mount=type=volume,source=${VOLNAME},destination=${MOUNT_TARGET}" >> $CONTAINER_FILE
    echo "Network=sandfly-net" >> $CONTAINER_FILE
    if [ "$t_cgroup_mgr" != "systemd" ]; then
        echo "PodmanArgs=--cgroups=enabled --log-opt 'max-size=${LOG_MAX_SIZE}' --log-opt 'max-file=5' --tty" >> $CONTAINER_FILE
    else
        echo "PodmanArgs=--log-opt 'max-size=${LOG_MAX_SIZE}' --log-opt 'max-file=5' --tty" >> $CONTAINER_FILE
    fi
    echo "ShmSize=${ram_total}k" >> $CONTAINER_FILE
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
            loginctl enable-linger $USER 2>/dev/null
            if [ $? -ne 0 ]; then
                sudo loginctl enable-linger $USER
            fi
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
