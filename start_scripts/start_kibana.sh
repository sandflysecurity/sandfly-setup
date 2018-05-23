#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2018 Sandfly Security LTD, All Rights Reserved.

docker network create sandfly-net
docker rm kibana

docker run --network sandfly-net \
-p 5601:5601 \
-d -e "elasticsearch.url=http://elasticsearch:9200" \
--network sandfly-net \
--name kibana \
docker.elastic.co/kibana/kibana:6.2.4
