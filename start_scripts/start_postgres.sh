#!/bin/bash

# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2021 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# After the first time Postgres starts, the admin password will be set in the
# database in the Docker volume we use, and setting the password through the
# docker run command will have no effect (e.g. it doesn't try to change it if
# a database already exists). If this is an initial install, the password we
# want to use should be in setup_data courtesy of the install.sh script.
POSTGRES_ADMIN_PASSWORD="unknown"
if [ -f ../setup/setup_data/postgres.admin.password.txt ]; then
    POSTGRES_ADMIN_PASSWORD=$(cat ../setup/setup_data/postgres.admin.password.txt)
fi

docker network create sandfly-net 2>/dev/null
docker rm sandfly-postgres 2>/dev/null

docker run \
--mount source=sandfly-pg14-db-vol,target=/var/lib/postgresql/data/pgdata \
-d \
-e POSTGRES_PASSWORD="$POSTGRES_ADMIN_PASSWORD" \
-e PGDATA=/var/lib/postgresql/data/pgdata \
--shm-size=1g \
--restart on-failure:5 \
--security-opt="no-new-privileges:true" \
--network sandfly-net \
--name sandfly-postgres \
-t \
postgres:14.0 \
-c shared_buffers=375MB \
-c effective_cache_size=1125MB \
-c maintenance_work_mem=96000kB \
-c checkpoint_completion_target=0.9 \
-c wal_buffers=11520kB \
-c default_statistics_target=100 \
-c random_page_cost=1.1 \
-c effective_io_concurrency=200 \
-c work_mem=4800kB \
-c min_wal_size=1GB \
-c max_wal_size=4GB \
-c max_worker_processes=2 \
-c max_parallel_workers_per_gather=1 \
-c max_parallel_workers=2 \
-c max_parallel_maintenance_workers=1
