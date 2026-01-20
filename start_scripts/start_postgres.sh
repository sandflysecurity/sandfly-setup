#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

IMAGE_BASE=${POSTGRES_IMAGE_BASE:-docker.io/library}
VERSION=18.1
VOLNAME=sandfly-pg18-db-vol

# All new installs will get Postgres 18 as set in VERSION above. But if
# this is an old install, we'll continue using Postgres 14.
if [ -f ../setup/setup_data/config.server.json ]; then
    if ! grep -q '"config_version": 4,' ../setup/setup_data/config.server.json >/dev/null; then
        VERSION=14.19
        VOLNAME=sandfly-pg14-db-vol
    fi
fi

LOG_MAX_SIZE="20m"

# Set CONTAINERMGR variable
. ../setup/setup_scripts/container_command.sh
if [ $? -ne 0 ]; then
    # Failed to find container runtime. The container_command script will
    # have printed an error.
    exit 1
fi

# Load images if offline bundle is present and not already loaded
../setup/setup_scripts/load_images.sh
if [ "$?" -ne 0 ]; then
  echo "Error loading container images."
  exit 1
fi

# After the first time Postgres starts, the admin password will be set in the
# database in the Docker volume we use, and setting the password through the
# docker run command will have no effect (e.g. it doesn't try to change it if
# a database already exists). If this is an initial install, the password we
# want to use should be in setup_data courtesy of the install.sh script.
POSTGRES_ADMIN_PASSWORD="unknown"
if [ -f ../setup/setup_data/postgres.admin.password.txt ]; then
    POSTGRES_ADMIN_PASSWORD=$(cat ../setup/setup_data/postgres.admin.password.txt)
fi

if [ -f ../setup/setup_data/config.server.json ]; then
    POOL_SIZE=$(grep -Eo '"pool_size":[[:space:]]*[[:digit:]]+' ../setup/setup_data/config.server.json | grep -Eo '[[:digit:]]+')
else
    POOL_SIZE=20
fi
if [ -z "$POOL_SIZE" ]; then
    POOL_SIZE=20
fi
if [ "$POOL_SIZE" -lt 20 ]; then
    echo "ERROR: server.db.postgres.pool_size must be between 20 and 500"
    exit 1
fi
if [ "$POOL_SIZE" -gt 500 ]; then
    echo "ERROR: server.db.postgres.pool_size must be between 20 and 500"
    exit 1
fi

if [ -f ../setup/setup_data/config.server.json ]; then
    POOL_SIZE_NODES=$(grep -Eo '"pool_size_nodes":[[:space:]]*[[:digit:]]+' ../setup/setup_data/config.server.json | grep -Eo '[[:digit:]]+')
else
    POOL_SIZE_NODES=30
fi
if [ -z "$POOL_SIZE_NODES" ]; then
    POOL_SIZE_NODES=30
fi
if [ "$POOL_SIZE_NODES" -lt 20 ]; then
    echo "ERROR: server.db.postgres.pool_size_nodes must be between 20 and 500"
    exit 1
fi
if [ "$POOL_SIZE_NODES" -gt 500 ]; then
    echo "ERROR: server.db.postgres.pool_size_nodes must be between 20 and 500"
    exit 1
fi

if [ -f ../setup/setup_data/config.server.json ]; then
    RESULT_WORKERS=$(grep -Eo '"result_workers":[[:space:]]*[[:digit:]]+' ../setup/setup_data/config.server.json | grep -Eo '[[:digit:]]+')
else
    RESULT_WORKERS=20
fi
if [ -z "$RESULT_WORKERS" ]; then
    RESULT_WORKERS=20
fi
if [ "$RESULT_WORKERS" -lt 10 ]; then
    echo "ERROR: server.db.postgres.result_workers must be between 10 and 500"
    exit 1
fi
if [ "$RESULT_WORKERS" -gt 500 ]; then
    echo "ERROR: server.db.postgres.result_workers must be between 10 and 500"
    exit 1
fi

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
work_mem=$(( ($ram_postgres - $shared_buffers) / ($max_connections * 3) / $parallel_workers ))
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

$CONTAINERMGR network create sandfly-net 2>/dev/null
$CONTAINERMGR rm sandfly-postgres 2>/dev/null

$CONTAINERMGR run \
--mount type=volume,source=${VOLNAME},target=/var/lib/postgresql/data \
-d \
-e POSTGRES_PASSWORD="$POSTGRES_ADMIN_PASSWORD" \
-e PGDATA=/var/lib/postgresql/data \
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
    echo "Environment=POSTGRES_PASSWORD=${POSTGRES_ADMIN_PASSWORD} PGDATA=/var/lib/postgresql/data" >> $CONTAINER_FILE
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
    echo "Mount=type=volume,source=${VOLNAME},destination=/var/lib/postgresql/data" >> $CONTAINER_FILE
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
