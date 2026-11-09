#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Upgrades the Sandfly Postgres 14 database to Postgres 18 in place.
#
# Sandfly and Postgres must be shut down first (shutdown_sandfly.sh). Once
# this script finishes, start Sandfly as usual; start_postgres.sh will run
# Postgres 18.
#
# The upgrade uses "pg_upgrade --link", which hard-links the existing data
# files into the new cluster rather than copying them. It takes seconds to a
# few minutes regardless of database size and needs very little free disk
# space. The data stays in the sandfly-pg14-db-vol volume (Docker volumes
# cannot be renamed), moved to the 18/docker directory within it.
#
# If the upgrade fails, the volume is restored to its original Postgres 14
# state and Sandfly can be started on Postgres 14 as before. If the script
# is interrupted, run it again to resume or roll back.
#
# Once the upgrade completes, the Postgres 14 data is deleted and it is not
# possible to go back to Postgres 14 except by restoring a backup.
#
# Pass -y to skip the confirmation prompt.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

IMAGE_BASE=${POSTGRES_IMAGE_BASE:-docker.io/library}
OLD_VOL=sandfly-pg14-db-vol
BIN_VOL=sandfly-pg14-upgrade-bin
LOG_FILE=$(pwd)/upgrade_postgres-$(date '+%Y%m%d-%H%M%S').log
START_SCRIPTS=$(cd ../../start_scripts && pwd)

PG_VERSION_14=$(grep -oP 'VERSION=\K(14\.[0-9]+)' "$START_SCRIPTS/start_postgres.sh" | head -n1)
PG_VERSION_18=$(grep -oP 'VERSION=\K(18\.[0-9]+)' "$START_SCRIPTS/start_postgres.sh" | head -n1)
if [ -z "$PG_VERSION_14" ] || [ -z "$PG_VERSION_18" ]; then
    echo "ERROR: Unable to determine Postgres versions from start_postgres.sh." >&2
    exit 1
fi
IMAGE_14=${IMAGE_BASE}/postgres:${PG_VERSION_14}
IMAGE_18=${IMAGE_BASE}/postgres:${PG_VERSION_18}

# Set CONTAINERMGR variable
. ../setup_scripts/container_command.sh
if [ $? -ne 0 ]; then
    # Failed to find container runtime. The container_command script will
    # have printed an error.
    exit 1
fi

# Sandfly server and Postgres must both be stopped.
for container in sandfly-server sandfly-postgres; do
    running=$($CONTAINERMGR inspect --format="{{.State.Running}}" $container 2> /dev/null)
    if [ "${running}z" = "truez" ]; then
        echo ""
        echo "****************************** ERROR ******************************"
        echo "* The $container container is running."
        echo "*"
        echo "* Please shut down Sandfly with the following script:"
        echo "*   $START_SCRIPTS/shutdown_sandfly.sh"
        echo "*"
        echo "* Then run this script again."
        echo "****************************** ERROR ******************************"
        echo ""
        exit 1
    fi
done

# Under Podman, systemd will restart Postgres if its container file is still
# installed. shutdown_sandfly.sh removes it.
if [ "$CONTAINERMGR" = "podman" ]; then
    TARGET_DIR=~/.config/containers/systemd
    if [ $(id -u) -eq 0 ]; then
        TARGET_DIR=/etc/containers/systemd
    fi
    if [ -f $TARGET_DIR/sandfly-postgres.container ]; then
        echo ""
        echo "****************************** ERROR ******************************"
        echo "* The systemd container file for sandfly-postgres is installed:"
        echo "*   $TARGET_DIR/sandfly-postgres.container"
        echo "*"
        echo "* Please shut down Sandfly with the following script:"
        echo "*   $START_SCRIPTS/shutdown_sandfly.sh"
        echo "*"
        echo "* Then run this script again."
        echo "****************************** ERROR ******************************"
        echo ""
        exit 1
    fi
fi

# start_postgres.sh prefers these volumes over the pg14 volume, and they
# only ever hold Postgres 18 data.
for vol in sandfly-pg-db-vol sandfly-pg18-db-vol; do
    if $CONTAINERMGR volume inspect $vol >/dev/null 2>&1; then
        echo "The $vol volume exists; Sandfly is already using Postgres 18."
        exit 0
    fi
done

if ! $CONTAINERMGR volume inspect $OLD_VOL >/dev/null 2>&1; then
    echo "ERROR: No Sandfly Postgres 14 database volume ($OLD_VOL) was found." >&2
    exit 1
fi

# Make sure both Postgres images are available. load_images.sh loads them
# from the offline bundle if present; otherwise pull them.
../setup_scripts/load_images.sh
if [ "$?" -ne 0 ]; then
    echo "Error loading container images."
    exit 1
fi
for image in $IMAGE_14 $IMAGE_18; do
    if ! $CONTAINERMGR image inspect $image >/dev/null 2>&1; then
        echo "*** Pulling $image"
        if ! $CONTAINERMGR pull $image; then
            echo "ERROR: Unable to pull $image." >&2
            exit 1
        fi
    fi
done

if [ "$1" != "-y" ]; then
    echo ""
    echo "********************************* WARNING *********************************"
    echo "*                                                                         *"
    echo "* This will upgrade the Sandfly database from Postgres 14 to Postgres 18. *"
    echo "*                                                                         *"
    echo "* Once the upgrade completes, it is not possible to go back to Postgres   *"
    echo "* 14 except by restoring a backup. Please make sure you have a backup     *"
    echo "* of the database before continuing.                                      *"
    echo "*                                                                         *"
    echo "********************************* WARNING *********************************"
    echo ""
    read -p "Are you sure you want to upgrade (type YES)? " RESPONSE
    if [ "$RESPONSE" != "YES" ]; then
        echo "Aborting upgrade."
        exit 1
    fi
fi

# Remove the stopped Postgres container so it can't be restarted (e.g. by a
# Docker daemon restart) against the volume while it is being upgraded.
# start_postgres.sh creates a new one.
$CONTAINERMGR rm -v sandfly-postgres >/dev/null 2>&1

# pg_upgrade needs the Postgres 14 and 18 binaries in the same container.
# Both images are built on the same Debian release, so the Postgres 14
# binaries run in the Postgres 18 image. Copy them into a temporary volume
# to mount there.
echo "*** Copying Postgres 14 binaries from $IMAGE_14"
$CONTAINERMGR volume rm $BIN_VOL >/dev/null 2>&1
$CONTAINERMGR run --rm --network none \
    --mount type=volume,source=$BIN_VOL,target=/pg14 \
    --entrypoint sh $IMAGE_14 \
    -c 'cp -a /usr/lib/postgresql/14/. /pg14/ && cp -a /usr/share/postgresql/14 /pg14/share'
if [ $? -ne 0 ]; then
    echo "ERROR: Unable to copy Postgres 14 binaries." >&2
    $CONTAINERMGR volume rm $BIN_VOL >/dev/null 2>&1
    exit 1
fi

# This runs as root inside the Postgres 18 container, with the data volume
# mounted at /var/lib/postgresql. The Postgres 14 data at the root of the
# volume is moved to 14/data, upgraded into 18/docker, and then deleted.
#
# Every step either can be repeated or is guarded by a check of the volume
# contents, so an interrupted run can be resumed by running it again. The
# .sandfly-upgrade-done marker records that pg_upgrade succeeded; before it
# exists, any failure rolls back to the original Postgres 14 layout.
UPGRADE_SCRIPT=$(cat <<'EOF'
set -euo pipefail

V=/var/lib/postgresql
OLD=$V/14/data
NEW=$V/18/docker
STAGE=$V/.sandfly-upgrade-stage
DONE=$V/18/.sandfly-upgrade-done
B14=/usr/lib/postgresql/14/bin
B18=/usr/lib/postgresql/18/bin
SOCKDIR=/var/run/postgresql

log() { echo "*** $*"; }
as_pg() { gosu postgres "$@"; }

# Move the old cluster from the volume root to 14/data, via a staging
# directory so an interrupted move can be completed.
relocate_old() {
    if [ -d "$STAGE" ] || [ -s "$V/PG_VERSION" ]; then
        log "Moving Postgres 14 data to 14/data within the volume"
        mkdir -p "$STAGE"
        chown postgres:postgres "$STAGE"
        chmod 700 "$STAGE"
        find "$V" -mindepth 1 -maxdepth 1 ! -name .sandfly-upgrade-stage \
            ! -name 14 ! -name 18 -exec mv -t "$STAGE" {} +
        mkdir -p "$V/14"
        chown postgres:postgres "$V/14"
        mv -T "$STAGE" "$OLD"
    fi
}

# Undo everything before the upgrade was committed: restore pg_control
# (renamed by pg_upgrade when linking starts), discard the new cluster, and
# move the old cluster back to the volume root. The new cluster is never
# started outside pg_upgrade before the commit, so the old cluster's data
# files are unmodified.
rollback() {
    log "Upgrade failed; restoring the Postgres 14 database"
    if [ -f "$OLD/global/pg_control.old" ] && [ ! -f "$OLD/global/pg_control" ]; then
        mv "$OLD/global/pg_control.old" "$OLD/global/pg_control"
    fi
    if [ -d "$NEW/pg_upgrade_output.d" ]; then
        log "pg_upgrade logs:"
        find "$NEW/pg_upgrade_output.d" -name '*.log' -type f \
            -exec tail -n 50 {} + || true
    fi
    rm -rf "$V/18"
    if [ -d "$OLD" ]; then
        mv -T "$OLD" "$STAGE"
    fi
    if [ -d "$STAGE" ]; then
        find "$STAGE" -mindepth 1 -maxdepth 1 -exec mv -t "$V" {} +
        rmdir "$STAGE"
    fi
    rm -rf "$V/14"
    log "The database has been restored to Postgres 14."
}

on_exit() {
    local rc=$?
    if [ $rc -ne 0 ] && [ ! -e "$DONE" ]; then
        set +e
        as_pg "$B14/pg_ctl" -D "$OLD" -m immediate stop >/dev/null 2>&1
        as_pg "$B18/pg_ctl" -D "$NEW" -m immediate stop >/dev/null 2>&1
        rollback
    fi
    exit $rc
}

# After the upgrade is committed: delete the old cluster and finish up in
# the new one. Safe to repeat if interrupted.
finalize() {
    log "Deleting Postgres 14 data"
    rm -rf "$V/14" "$V/18/delete_old_cluster.sh"

    log "Starting Postgres 18 to finish the upgrade"
    as_pg "$B18/pg_ctl" -D "$NEW" -o "-c listen_addresses=''" -w -t 3600 \
        -l "$V/18/postgres-upgrade.log" start
    if [ -f "$V/18/update_extensions.sql" ]; then
        log "Updating extensions"
        as_pg "$B18/psql" -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
            -f "$V/18/update_extensions.sql"
        rm -f "$V/18/update_extensions.sql"
    fi
    # pg_upgrade in Postgres 18 carries over planner statistics; this only
    # analyzes the tables that don't have any.
    log "Updating missing planner statistics"
    as_pg "$B18/vacuumdb" -U postgres --all --analyze-in-stages \
        --missing-stats-only || log "WARNING: vacuumdb failed; autovacuum will update statistics."
    as_pg "$B18/pg_ctl" -D "$NEW" -m fast -w -t 3600 stop
    rm -f "$V/18/postgres-upgrade.log" "$DONE"
}

# The Postgres 14 binaries were copied to /usr/lib/postgresql/14; they also
# need their share directory at the location they were built with.
mkdir -p /usr/share/postgresql
ln -sfn /usr/lib/postgresql/14/share /usr/share/postgresql/14
if ! "$B14/postgres" --version >/dev/null; then
    log "ERROR: The Postgres 14 binaries cannot run in the Postgres 18 image."
    exit 1
fi

if [ -e "$DONE" ]; then
    log "Resuming a previous upgrade"
    finalize
    log "Upgrade complete."
    exit 0
fi
if [ -s "$NEW/PG_VERSION" ] && [ ! -e "$V/14" ] && [ ! -e "$STAGE" ]; then
    log "The database has already been upgraded to Postgres 18."
    exit 0
fi

avail_kb=$(df -Pk "$V" | awk 'NR==2 {print $4}')
if [ "$avail_kb" -lt 1048576 ]; then
    log "ERROR: At least 1GB of free disk space is needed for the upgrade;"
    log "only ${avail_kb}kB is available."
    exit 1
fi

trap on_exit EXIT
trap 'exit 1' INT TERM

relocate_old
if [ "$(cat "$OLD/PG_VERSION" 2>/dev/null)" != "14" ]; then
    log "ERROR: No Postgres 14 data found in the volume."
    exit 1
fi

# Clean up after a previous attempt that was interrupted before it could
# roll back.
if [ -f "$OLD/global/pg_control.old" ] && [ ! -f "$OLD/global/pg_control" ]; then
    mv "$OLD/global/pg_control.old" "$OLD/global/pg_control"
fi
rm -rf "$V/18"

# Start and stop the old cluster. This runs crash recovery if it was not
# shut down cleanly (pg_upgrade requires a clean shutdown), and lets us read
# the settings the new cluster must be created with.
log "Checking the Postgres 14 database"
as_pg "$B14/pg_ctl" -D "$OLD" -o "-c listen_addresses='' -c unix_socket_directories=$SOCKDIR" \
    -w -t 3600 -l /tmp/pg14.log start || { cat /tmp/pg14.log; exit 1; }
IFS='|' read -r ENCODING COLLATE CTYPE < <(as_pg "$B18/psql" -X -At -U postgres -d postgres -c \
    "SELECT pg_encoding_to_char(encoding), datcollate, datctype FROM pg_database WHERE datname = 'template0'")
as_pg "$B14/pg_ctl" -D "$OLD" -m fast -w -t 3600 stop
if [ -z "$ENCODING" ] || [ -z "$COLLATE" ] || [ -z "$CTYPE" ]; then
    log "ERROR: Unable to read the Postgres 14 database encoding and locale."
    exit 1
fi

CONTROLDATA=$(as_pg "$B14/pg_controldata" "$OLD")
CHECKSUMS=$(echo "$CONTROLDATA" | awk -F': *' '/^Data page checksum version/ {print $2}')
WALSEG=$(echo "$CONTROLDATA" | awk -F': *' '/^Bytes per WAL segment/ {print $2}')
if [ "$CHECKSUMS" = "0" ]; then
    CHECKSUM_OPT=--no-data-checksums
else
    CHECKSUM_OPT=--data-checksums
fi

log "Creating the Postgres 18 database ($ENCODING, $COLLATE, checksums $CHECKSUMS)"
mkdir -p "$NEW"
chown postgres:postgres "$V" "$V/18" "$NEW"
chmod 700 "$NEW"
as_pg "$B18/initdb" -D "$NEW" -U postgres -E "$ENCODING" \
    --lc-collate="$COLLATE" --lc-ctype="$CTYPE" \
    --wal-segsize=$((WALSEG / 1024 / 1024)) --auth=trust $CHECKSUM_OPT >/dev/null

log "Running pg_upgrade"
cd "$V/18"
as_pg "$B18/pg_upgrade" --link --jobs="$(nproc)" -U postgres \
    --old-bindir="$B14" --new-bindir="$B18" \
    --old-datadir="$OLD" --new-datadir="$NEW" \
    --socketdir="$SOCKDIR" | sed '/^Upgrade Complete/,$d'

# Carry over client authentication and ALTER SYSTEM settings. The new
# postgresql.conf is kept; the old one is saved for reference.
for f in pg_hba.conf pg_ident.conf postgresql.auto.conf; do
    if [ -f "$OLD/$f" ]; then
        cp -p "$OLD/$f" "$NEW/$f"
    fi
done
cp -p "$OLD/postgresql.conf" "$NEW/postgresql.conf.pg14"
# Fail (and roll back) now if the carried-over settings are invalid in
# Postgres 18. This parses the config without starting the server.
as_pg "$B18/postgres" -D "$NEW" -C server_version >/dev/null

# Commit. From here on, the upgrade only moves forward.
touch "$DONE"
trap - EXIT INT TERM

finalize
log "Upgrade complete."
EOF
)

echo "*** Upgrading Postgres (log: $LOG_FILE)"
$CONTAINERMGR run --rm --network none \
    --shm-size=256m \
    --mount type=volume,source=$OLD_VOL,target=/var/lib/postgresql \
    --mount type=volume,source=$BIN_VOL,target=/usr/lib/postgresql/14 \
    --entrypoint bash $IMAGE_18 -c "$UPGRADE_SCRIPT" 2>&1 | tee "$LOG_FILE"
rc=${PIPESTATUS[0]}

$CONTAINERMGR volume rm $BIN_VOL >/dev/null 2>&1

if [ $rc -ne 0 ]; then
    echo ""
    echo "********************************** ERROR **********************************"
    echo "*                                                                         *"
    echo "* The Postgres upgrade did not complete. See the messages above, and the  *"
    echo "* log file:                                                               *"
    echo "*   $LOG_FILE"
    echo "*                                                                         *"
    echo "* If the database was restored to Postgres 14, Sandfly can be started as  *"
    echo "* usual. Otherwise, run this script again to resume the upgrade. If the   *"
    echo "* problem persists, please contact Sandfly support with the log file.     *"
    echo "*                                                                         *"
    echo "********************************** ERROR **********************************"
    echo ""
    exit 1
fi

echo ""
echo "*** The database has been upgraded to Postgres 18. Start Sandfly as usual;"
echo "*** start_postgres.sh will run Postgres 18."
echo ""
