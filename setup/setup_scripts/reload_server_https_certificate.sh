#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

#############################################################################
# Reload the server's TLS certificate.                                      #
#                                                                           #
# If you have placed updated certificate files in the server_ssl_cert       #
# directory (cert.pem and privatekey.pem), run this script to tell the      #
# server to reload them without restarting.                                 #
#############################################################################

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Set CONTAINERMGR variable
. ./container_command.sh
if [ $? -ne 0 ]; then
    # Failed to find container runtime. The container_command script will
    # have printed an error.
    exit 1
fi

if [ -z "$($CONTAINERMGR ps -q -f name=sandfly-server)" ]; then
    echo "The sandfly-server container is not running."
    exit 1
fi

echo "Sending reload signal to server..."
# The server is always PID 1 inside the container
$CONTAINERMGR exec sandfly-server bash -c 'kill -HUP 1'

if [ $? -eq 0 ]; then
    echo "Reload signal sent. The server will reload its TLS certificate."
else
    echo "Failed to send reload signal."
    exit 1
fi
