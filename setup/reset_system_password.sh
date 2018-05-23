#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2018 Sandfly Security LTD, All Rights Reserved.

# Used to generate a new API password the scanning nodes use to post results data. This shouldn't be used unless
# requested by Sandfly.

WORKING_DIR=$PWD

# Uncomment and change this if you wish to override what elastic DB for Sandfly so to use. The default is to use
# sandfly container version, but you can use your own cluster if you wish.
#export ELASTIC_SERVER="ip_addr_or_hostname_here"

docker network create sandfly-net
docker rm sandfly-server-mgmt


docker run --name sandfly-server-mgmt \
--network sandfly-net \
-e ELASTIC_SERVER \
-it sandfly/sandfly-server-mgmt:latest /usr/local/sandfly/utils/reset_system_password.sh



