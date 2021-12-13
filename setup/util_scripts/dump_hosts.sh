#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

# Used to bulk dump registered hosts from DB to JSON and CSV formatted files for legacy installs.

cat << EOF

******************************************************************************
Host Dump Script

This script will dump all host information to a JSON file and hostname and
credential id to a CSV file. This will allow legacy Sandfly users to quickly
add back hosts during upgrade.
******************************************************************************

EOF

if ! command -v jq &> /dev/null
then
    echo "the 'jq' command could not be found and is required to run this script."
    exit 1
fi

if ! command -v curl &> /dev/null
then
    echo "The 'curl' command could not be found and is required to run this script."
    exit 1
fi


read -p "Hostname for Sandfly server: " HOSTNAME
if [[ "$HOSTNAME" == "" ]]; then
    echo "Must supply a hostname."
    exit 1
fi

read -p "Password for Sandfly server: " PASSWORD
if [[ "$PASSWORD" == "" ]]; then
    echo "Must supply a password."
    exit 1
fi

echo "Pulling host data from: $HOSTNAME"

ACCESS_TOKEN=$(curl -s -k --request POST --header "Content-Type: application/json" --url https://"$HOSTNAME"/v4/auth/login \
--data "{\"username\":\"admin\",\"password\":\"$PASSWORD\"}" |  jq -r ".access_token")

if [[ "$ACCESS_TOKEN" == "null" ]]; then
  echo "Couldn't get access token for REST API. Check hostname and credentials and try again."
  exit 1
fi
echo "Password OK. Dumping hosts."

HOST_JSON=$(curl -s -k --request GET --header "Content-Type: application/json" --header "Authorization: Bearer $ACCESS_TOKEN" \
--url https://"$HOSTNAME"/v4/hosts | jq ".")
if [[ "$HOST_JSON" == "null" ]]; then
  echo "Host list appears empty. Nothing to dump."
  exit 1
fi

echo "Saving host JSON to ./sandfly.hosts.json"
echo "$HOST_JSON" > sandfly.hosts.json

echo "Saving hostname and credential ID to ./sandfly.hosts.csv"
echo $HOST_JSON | jq -r '.data[] | "\(.hostname), \(.credentials_id)"' > sandfly.hosts.csv

echo "Done!"