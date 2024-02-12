#!/bin/sh
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2024 Sandfly Security LTD, All Rights Reserved.

# Informational script to replace the old Rabbit startup script. Without
# putting this placeholder in place, the existing script would result in
# an error after upgrade if someone tries to run it until the cleanup script
# gets a chance to remove it.

echo
echo "********************************************************************"
echo "*                                                                  *"
echo "* Sandfly no longer uses RabbitMQ, so there is no need to start    *"
echo "* the Rabbit container. This script will be removed automatically  *"
echo "* when you start the server.                                       *"
echo "*                                                                  *"
echo "********************************************************************"
echo
