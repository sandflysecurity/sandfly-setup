#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2021 Sandfly Security LTD, All Rights Reserved.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Determine if we need to use the sudo command to control Docker
SUDO=""
if [ $(id -u) -ne 0 ]; then
    docker version >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        SUDO="sudo"
    fi
fi

### Start ElasticSearch if not already running
esresult=$($SUDO docker inspect --format="{{.State.Running}}" elasticsearch 2> /dev/null)
if [ "${esresult}z" != "truez" ]; then
    echo "*** Starting ElasticSearch."
    $SUDO ./start_elastic.sh
    if [ $? -ne 0 ]; then
        echo "*** ERROR: Error starting ElasticSearch container; cannot proceed."
        exit 2
    fi
    temp_cnt=30
    while [[ ${temp_cnt} -gt 0 ]];
    do
        printf "\rWaiting %2d second(s) for Elasticsearch to start and settle down." ${temp_cnt}
        sleep 1
        ((temp_cnt--))
    done
    echo ""
else
    echo "*** ElasticSearch container already running."
fi

### Start RabbitMQ if not already running
esresult=$($SUDO docker inspect --format="{{.State.Running}}" sandfly-rabbit 2> /dev/null)
if [ "${esresult}z" != "truez" ]; then
    echo "*** Starting RabbitMQ server."
    $SUDO ./start_rabbit.sh
    if [ $? -ne 0 ]; then
        echo "*** ERROR: Error starting RabbitMQ container; cannot proceed."
        exit 2
    fi
    echo "Waiting for RabbitMQ to configure and start. This will take about 45 seconds."
    # Wait a maximum of 3 minutes
    TIMER=180
    while true; do
        $SUDO docker logs sandfly-rabbit 2>&1 | grep "Server startup complete" > /dev/null
        if [ $? -eq 0 ]; then
            echo
            break
        fi
        TIMER=$(expr $TIMER - 5)
        if [ $TIMER -le 0 ]; then
            echo "*** ERROR: the sandfly-rabbit container took too long to configure and start."
            echo "*** Automatic startup could not complete."
            exit 2
        fi
        echo -n "."
        sleep 5
    done
else
    echo "*** RabbitMQ container already running."
fi

### Start sandfly-server if not already running
esresult=$($SUDO docker inspect --format="{{.State.Running}}" sandfly-server 2> /dev/null)
if [ "${esresult}z" != "truez" ]; then
    echo "*** Starting Sandfly Server."
    $SUDO ./start_server.sh
else
    echo "*** Sandfly Server container already running."
fi
