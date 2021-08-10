#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

RAM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
# Elasticsearch recommends at least 50% of memory be set aside for heap use. If you want to set this
# manually, you can change the value below to what you want to use.
RAM_HALF=$(($RAM_TOTAL/2))

echo "Total system RAM: $RAM_TOTAL MB"
echo "Recommended elasticsearch heap (approx 50% RAM): $RAM_HALF MB"
if [ -n "$ES_RAM_OVERRIDE" ]; then
	if [ "$ES_RAM_OVERRIDE" -ge 1 ]; then
		RAM_HALF="$ES_RAM_OVERRIDE"
		echo "Overriding elasticsearch heap size with ES_RAM_OVERRIDE: $RAM_HALF MB"
	fi
fi
echo "Setting elasticsearch heap to: $RAM_HALF MB"

# Needed for elasticsearch in production environments.
if [ $(sysctl -n vm.max_map_count) -lt 262144 ]; then
	echo "Setting vm.max_map_count"
	if [ $EUID -eq 0 ]; then
		sysctl -w vm.max_map_count=262144
	else
		echo "...with sudo"
		sudo sysctl -w vm.max_map_count=262144
	fi
else
	echo "vm.max_map_count already acceptable value:"
	sysctl vm.max_map_count
fi

docker network create sandfly-net 2>/dev/null
docker rm elasticsearch 2>/dev/null

docker run --mount source=sandfly-elastic-db-vol,target=/usr/share/elasticsearch/data \
-d \
-e "http.host=0.0.0.0" \
-e "xpack.security.enabled=false" \
-e "transport.host=127.0.0.1" \
-e "bootstrap.memory_lock=true" \
-e "discovery.type=single-node" \
-e "search.max_open_scroll_context=2000" \
--ulimit memlock=-1:-1 \
--ulimit nofile=65535:65535 \
--env ES_JAVA_OPTS="-Xms${RAM_HALF}m -Xmx${RAM_HALF}m" \
--restart on-failure:5 \
--security-opt="no-new-privileges:true" \
--network sandfly-net \
--name elasticsearch \
-t docker.elastic.co/elasticsearch/elasticsearch:7.13.4