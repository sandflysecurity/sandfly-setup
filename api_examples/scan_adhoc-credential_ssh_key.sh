#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2022 Sandfly Security LTD, All Rights Reserved.

# A reference script for the Sandfly API, change data where appropriate

cat << EOF

******************************************************************************
Sandfly API Reference Script Example

This script will attempt to authenticate, do adhoc scan, and output results.
ITERATION: Uses the "ssh_key" credentials_type for the host credentials.

DOC: https://api.sandflysecurity.com/#post-/scan/adhoc
******************************************************************************

EOF

# Set changeable variables
APIVERSION="v4"             # Version of the API used by the Sandfly Server
APIPATH="scan/adhoc"        # API command to call on the Sandfly Server
JQFILTER="."                # Filter for jq in the output section
REQUESTMETHOD="POST"        # HTTP request method for data calls
REQUESTDATA='{'\
'"hosts":{'\
'"ip_list":['\
'"192.168.0.1",'\
'"192.168.0.2"'\
'],'\
'"ssh_port":22,'\
'"credentials_id":"ssh_login_example"'\
'},'\
'"credentials":{'\
'"ssh_login_example":{'\
'"credentials_type":"ssh_key",'\
'"username":"root",'\
'"ssh_key_b64":"INSERT_YOUR_SSH_PRIVATE_KEY_ENCODED_IN_BASE64_HERE"'\
'}'\
'},'\
'"sandfly_list":['\
'"user_history_anti_forensics",'\
'"process_persistence_cron_malicious"'\
'],'\
'"tags":['\
'"api_example_tag",'\
'"ssh_example_tag"'\
']'\
'}'                         # Data for any POST calls, leave blank for GET

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
OUTPUT_JSON=$(curl -s -k --request "$REQUESTMETHOD" \
	--header "Content-Type: application/json" \
	--header "Authorization: Bearer $ACCESS_TOKEN" \
	--url https://"$HOSTNAME"/"$APIVERSION"/"$APIPATH" \
	--data "$REQUESTDATA")

OUTPUT_STATUS=$(echo $OUTPUT_JSON | jq -r ".status")
OUTPUT_DETAIL=$(echo $OUTPUT_JSON | jq -r ".detail")

if [[ "$OUTPUT_JSON" == "null" ]]; then
  echo "CALL STATUS: Failed, no JSON response."
  exit 1
elif [[ "$OUTPUT_STATUS" -gt 399 ]]; then
  echo "CALL STATUS: Failed, CODE:$OUTPUT_STATUS - $OUTPUT_DETAIL"
  exit 1
else
  echo "CALL STATUS: Passed, the output is:"
  echo "$OUTPUT_JSON" | jq "$JQFILTER"
fi

# Attempt to get and output the scan result data
echo ""
echo -e "\033[33;5;7mWaiting a minute for the scanning to finish...\033[0m"
echo ""
sleep 60

# Loop for each host
ROW=0
while true; do
	HOSTID=$(echo $OUTPUT_JSON | jq -r ".[] | keys[$ROW]")
	RUNID=$(echo $OUTPUT_JSON | jq -r ".[] | to_entries | .[$ROW].value")
	ROW=$(expr $ROW + 1)

	if [ "$RUNID" = "null" ]; then
		break
	fi

	echo ""
	echo "Scan results for host: $HOSTID"

	RESULT_JSON=$(curl -s -k --request "$REQUESTMETHOD" \
	--header "Content-Type: application/json" \
	--header "Authorization: Bearer $ACCESS_TOKEN" \
	--url https://"$HOSTNAME"/"$APIVERSION"/results \
	--data "{\"size\":100,\"summary\":true,\"filter\":{\"items\":[{\"columnField\":\"header.run_id\",\"operatorValue\":\"equals\",\"value\":\"$RUNID\"}]}}")

	RESULT_STATUS=$(echo $RESULT_JSON | jq -r ".status")
	RESULT_DETAIL=$(echo $RESULT_JSON | jq -r ".detail")

	if [[ "$RESULT_JSON" == "null" ]]; then
	  echo "CALL STATUS: Failed, no JSON response."
	  exit 1
	elif [[ "$RESULT_STATUS" -gt 399 ]]; then
	  echo "CALL STATUS: Failed, CODE:$RESULT_STATUS - $RESULT_DETAIL"
	  exit 1
	else
	  echo "CALL STATUS: Passed, the output is:"
	  echo "$RESULT_JSON" | jq
	fi
done
# NOTE: host settings and/or credentials were incorrect if output is:
# { "data": [], "more_results": false, "scroll_id": null, "total": 0 }

# Wrap up the example
echo ""
echo "Script Finished!"
