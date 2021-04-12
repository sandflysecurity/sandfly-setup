#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

# Used to bulk dump custom sandfly data.

cat << EOF

******************************************************************************
Custom Sandfly Dump Script

This script will dump all custom sandfly data to a backup JSON file.
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

echo "Pulling custom sandfly data from: $HOSTNAME"

ACCESS_TOKEN=$(curl -s -k --request POST --header "Content-Type: application/json" --url https://"$HOSTNAME"/v3/auth/login \
--data "{\"username\":\"admin\",\"password\":\"$PASSWORD\"}" |  jq -r ".access_token")
if [[ "$ACCESS_TOKEN" == "null" ]]; then
  echo "Couldn't get access token for REST API. Check hostname and credentials and try again."
  exit 1
fi
echo "Password OK. Dumping custom sandfly data."

SANDFLY_JSON=$(curl -s -k --request GET --header "Content-Type: application/json" --header "Authorization: Bearer $ACCESS_TOKEN" \
--url https://"$HOSTNAME"/v3/sandflies/custom/backup | jq ".")
if [[ "$SANDFLY_JSON" == "null" ]]; then
  echo "Custom sandfly list appears empty. Nothing to dump."
  exit 1
fi

echo "Saving custom sandfly JSON to ./sandfly.custom_sandflies.json"
echo "$SANDFLY_JSON" > sandfly.custom_sandflies.json

echo "Done!"