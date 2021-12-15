#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

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

# Double-check that vm.max_map_count *really* got set.
if [ $(sysctl -n vm.max_map_count) -lt 262144 ]; then
	echo "******************************************************************"
	echo "*                                                                *"
	echo "* ERROR: this script attempted to set vm.max_map_count to 262144 *"
	echo "*        but the value is still lower. This setting is required  *"
	echo "*        for reliable ElasticSearch operation; please change the *"
	echo "*        setting manually (e.g. add vm.max_map_count=262144 to   *"
	echo "*        /etc/sysctl.conf and restart the system) then run this  *"
	echo "*        script again to start ElasticSearch.                    *"
	echo "*                                                                *"
	echo "******************************************************************"
	exit 2
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
--restart on-failure:5 \
--security-opt="no-new-privileges:true" \
--network sandfly-net \
--name elasticsearch \
-t docker.elastic.co/elasticsearch/elasticsearch:7.14.1
