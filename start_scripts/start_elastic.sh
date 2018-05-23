#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2018 Sandfly Security LTD, All Rights Reserved.

# Needed for elasticsearch in production environments.
sysctl -w vm.max_map_count=262144

docker network create sandfly-net
docker rm elasticsearch

docker run --mount source=sandfly-elastic-db-vol,target=/usr/share/elasticsearch/data \
-d \
-e "http.host=0.0.0.0" \
-e "xpack.security.enabled=false" \
-e "transport.host=127.0.0.1" \
--env "ES_JAVA_OPTS=""-Xms1g -Xmx1g" \
--restart on-failure:5 \
--security-opt="no-new-privileges:true" \
--network sandfly-net \
--name elasticsearch \
-t docker.elastic.co/elasticsearch/elasticsearch:6.2.4
