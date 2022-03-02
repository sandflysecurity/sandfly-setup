#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2022 Sandfly Security LTD, All Rights Reserved.

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
