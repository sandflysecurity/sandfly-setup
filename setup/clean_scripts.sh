#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# This script cleans up leftover scripts from previous versions which are no
# longer applicable to the current version.

SETUP_DATA=setup_data
BACKUPFOLDER=$SETUP_DATA/backup/$(date '+%Y-%m-%d.%H%M')

if [ -f util_scripts/reset_db_hosts.sh ]; then
    mkdir -p $BACKUPFOLDER
    mv util_scripts/reset_db_hosts.sh $BACKUPFOLDER
fi

if [ -f util_scripts/reset_db_version.sh ]; then
    mkdir -p $BACKUPFOLDER
    mv util_scripts/reset_db_version.sh $BACKUPFOLDER
fi

if [ -f util_scripts/reset_license.sh ]; then
    mkdir -p $BACKUPFOLDER
    mv util_scripts/reset_license.sh $BACKUPFOLDER
fi

if [ -f ../start_scripts/start_elastic.sh ]; then
    mkdir -p $BACKUPFOLDER
    mv ../start_scripts/start_elastic.sh $BACKUPFOLDER
fi

# upgrade.sh renamed
if [ -f ./upgrade.sh ]; then
    mkdir -p $BACKUPFOLDER
    mv ./upgrade.sh $BACKUPFOLDER
fi

# 3.3.0 - old util/dump scripts are now part of api_examples
if [ -f util_scripts/dump_custom_sandflies.sh ]; then
    mkdir -p $BACKUPFOLDER
    mv util_scripts/dump_custom_sandflies.sh $BACKUPFOLDER
fi

if [ -f util_scripts/dump_hosts.sh ]; then
    mkdir -p $BACKUPFOLDER
    mv util_scripts/dump_hosts.sh $BACKUPFOLDER
fi
# End 3.3.0

# 5.0.0 - RabbitMQ no longer used; Elastic upgrade no longer supported
if [ -f ../start_scripts/start_rabbit.sh ]; then
    mkdir -p $BACKUPFOLDER
    mv ../start_scripts/start_rabbit.sh $BACKUPFOLDER
fi

if [ -f legacy_start_elastic.sh ]; then
    mkdir -p $BACKUPFOLDER
    mv legacy_start_elastic.sh $BACKUPFOLDER
fi

if [ -f migrate_es2pg.sh ]; then
    mkdir -p $BACKUPFOLDER
    mv migrate_es2pg.sh $BACKUPFOLDER
fi
# End 5.0.0

# 5.2.0 - Offline package now provided as part of release bundle
if [ -f util_scripts/offline_packager.sh ]; then
    mkdir -p $BACKUPFOLDER
    mv util_scripts/offline_packager.sh $BACKUPFOLDER
fi
# End 5.2.0

# 5.3.0 - unsupported installation method
if [ -f auto_install_allinone.sh ]; then
    mkdir -p $BACKUPFOLDER
    mv auto_install_allinone.sh $BACKUPFOLDER
fi
# End of 5.3.0
