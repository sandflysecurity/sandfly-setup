#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# A reference script for the Sandfly API, change data where appropriate

cat << EOF

******************************************************************************
Sandfly API Reference Script Example

This script will attempt to authenticate, get access token, and output it.

DOC: https://docs.sandflysecurity.com/reference/apilogin
******************************************************************************

EOF

# Set changeable variables
APIVERSION="v4"             # Version of the API used by the Sandfly Server

# Check for required commands
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

# Prompt for entering connection data
read -p "Hostname for Sandfly server: " HOSTNAME
if [[ "$HOSTNAME" == "" ]]; then
    echo "Must supply a hostname."
    exit 1
fi

read -s -p "Password for Sandfly admin user: " PASSWORD
if [[ "$PASSWORD" == "" ]]; then
    echo ""
    echo "Must supply a password."
    exit 1
fi

# Attempt to connect to the API and obtain the access token
echo ""
echo ""
echo "Attempting to connect to the Sandfly API at: $HOSTNAME"
echo ""

ACCESS_JSON=$(curl -s -k --request POST \
	--header "Content-Type: application/json" \
	--url https://"$HOSTNAME"/"$APIVERSION"/auth/login \
	--data "{\"username\":\"admin\",\"password\":\"$PASSWORD\"}")

ACCESS_TOKEN=$(echo $ACCESS_JSON | jq -r ".access_token")

if [[ "$ACCESS_JSON" == "" ]]; then
  echo "AUTH STATUS: Failed, did not receive data from the host. Check hostname and credentials and try again."
  exit 1
elif [[ "$ACCESS_TOKEN" == "null" ]]; then
  echo "AUTH STATUS: Failed, did not get access token for REST API. Check hostname and credentials and try again."
  exit 1
else
  echo "AUTH STATUS: Passed, access token obtained."
fi

# Attempt to get and output the data
echo "CALL STATUS: Passed, the output is:"

echo "$ACCESS_TOKEN"

# Wrap up the example
echo ""
echo "Script Finished!"
