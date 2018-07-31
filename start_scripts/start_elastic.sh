#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2018 Sandfly Security LTD, All Rights Reserved.

RAM_TOTAL=$(free -g | grep Mem | awk '{print $2}')
# Elasticsearch recommends at least 50% of memory be set aside for heap use. If you want to set this
# manually, you can change the value below to what you want to use.
RAM_HALF=$(($RAM_TOTAL/2))

echo "Total system RAM: $RAM_TOTAL gb"
echo "Setting elasticsearch heap (approx 50% RAM) to: $RAM_HALF gb"

# Needed for elasticsearch in production environments.
sysctl -w vm.max_map_count=262144

docker network create sandfly-net
docker rm elasticsearch

docker run --mount source=sandfly-elastic-db-vol,target=/usr/share/elasticsearch/data \
-d \
-e "http.host=0.0.0.0" \
-e "xpack.security.enabled=false" \
-e "transport.host=127.0.0.1" \
-e "bootstrap.memory_lock=true" \
--ulimit memlock=-1:-1 \
--ulimit nofile=65536:65536 \
--env ES_JAVA_OPTS="-Xms${RAM_HALF}g -Xmx${RAM_HALF}g" \
--restart on-failure:5 \
--security-opt="no-new-privileges:true" \
--network sandfly-net \
--name elasticsearch \
-t docker.elastic.co/elasticsearch/elasticsearch:6.3.1
