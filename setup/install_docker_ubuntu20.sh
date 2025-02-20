#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

sudo apt update
sudo apt install docker.io -y

sudo service docker start

if [ -f "/snap/bin/docker" ]; then
    echo ""
    echo "***************************** WARNING *****************************"
    echo "*                                                                 *"
    echo "* A version of Docker appears to be installed via Snap.           *"
    echo "*                                                                 *"
    echo "* Sandfly is only compatible with the apt version of Docker.      *"
    echo "* Having both versions installed will conflict with Sandfly.      *"
    echo "* Please remove the snap version before starting Sandfly.         *"
    echo "*                                                                 *"
    echo "*******************************************************************"
    echo ""
fi
