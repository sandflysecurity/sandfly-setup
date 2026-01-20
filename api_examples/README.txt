
This folder contains a set of scripts that demonstrate a variety of core functions of the Sandfly API,
including authentication, get / post operations, and performing scans.

These scripts can be used from any host that can run bash, curl, and jq commands and that can reach the
administrative web interface of your Sandfly server.

Documentation can be found here: https://docs.sandflysecurity.com/docs/sandfly-api

Full list of Sandfly API calls: https://api.sandflysecurity.com/

- add_credential.sh
    - This script will attempt to authenticate and add a credential.
    - https://docs.sandflysecurity.com/reference/addcredential

- add_hosts.sh
    - This script will attempt to authenticate and add one or more hosts.
    - https://docs.sandflysecurity.com/reference/addhosts

- auth_login.sh
    - This script will attempt to authenticate, get access token, and output it.
    - https://docs.sandflysecurity.com/reference/apilogin

- get_custom_sandflies.sh
    - This script will attempt to authenticate and output all custom sandflies.
    - https://docs.sandflysecurity.com/reference/backupsandflies

- get_hosts.sh
    - This script will attempt to authenticate and output all hosts.
    - https://docs.sandflysecurity.com/reference/gethosts

- get_results.sh
    - This script will attempt to authenticate and get up to 10 alarm results.
    - https://docs.sandflysecurity.com/reference/getresults

- get_sandflies-active.sh
    - This script will attempt to authenticate and output text of sandfly names.
    - ITERATION: Filter for the plaintext names of all "active" sandflies
    - https://docs.sandflysecurity.com/reference/getsandflies

- get_sandflies-active_process.sh
    - This script will attempt to authenticate and output text of sandfly names.
    - ITERATION: Filter for the plaintext names of all "active", process sandflies
    - https://docs.sandflysecurity.com/reference/getsandflies

- get_sandflies-all.sh
    - This script will attempt to authenticate and output text of sandfly names.
    - ITERATION: Filter for the plaintext names of all sandflies
    - https://docs.sandflysecurity.com/reference/getsandflies

- get_version.sh
    - This script will attempt to authenticate, get version data, and output it.
    - https://docs.sandflysecurity.com/reference/getsystemversion

- scan_adhoc-credential_ssh_key.sh
    - This script will attempt to authenticate, do adhoc scan, and output results.
    - ITERATION: Uses the "ssh_key" credentials_type for the host credentials.
    - https://docs.sandflysecurity.com/reference/startadhocscan

- scan_adhoc-credential_username.sh
    - This script will attempt to authenticate, do adhoc scan, and output results.
    - ITERATION: Uses the "username" credentials_type for the host credentials.
    - https://docs.sandflysecurity.com/reference/startadhocscan

- scan_hosts.sh
    - This script will attempt to authenticate and start host scanning tasks.
    - https://docs.sandflysecurity.com/reference/startscan

---

Find out more and get your free trial license here:

https://www.sandflysecurity.com/

Documentation here:

https://docs.sandflysecurity.com/

Copyright (c) Sandfly Security LTD, All Rights Reserved.
www.sandflysecurity.com
