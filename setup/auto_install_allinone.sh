#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2021 Sandfly Security LTD, All Rights Reserved.

## Exit codes:
##  0 = success
##  1 = script can be re-tried after correcting the problem
##  2 = manual intervention may be required to reset system before
##      running this script again

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Determine if we need to use the sudo command for docker
SUDO=""
if [ $(id -u) -ne 0 ]; then
    docker version >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        SUDO="sudo"
    fi
fi

cat << "__EOF__"


 _____                 _  __ _         _____                      _ _         
/  ___|               | |/ _| |       /  ___|                    (_) |        
\ `--.  __ _ _ __   __| | |_| |_   _  \ `--.  ___  ___ _   _ _ __ _| |_ _   _ 
 `--. \/ _` | '_ \ / _` |  _| | | | |  `--. \/ _ \/ __| | | | '__| | __| | | |
/\__/ / (_| | | | | (_| | | | | |_| | /\__/ /  __/ (__| |_| | |  | | |_| |_| |
\____/ \__,_|_| |_|\__,_|_| |_|\__, | \____/ \___|\___|\__,_|_|  |_|\__|\__, |
                     .          __/ |              .                     __/ |
                    //         |___/               \\                   |___/
                   //                               \\
                  //                                 \\
                 //                _._                \\
              .---.              .//|\\.              .---.
    ________ / .-. \_________..-~ _.-._ ~-..________ / .-. \_________ -sr
             \ ~-~ /   /H-     `-=.___.=-'     -H\   \ ~-~ /
               ~~~    / H          [H]          H \    ~~~
                     / _H_         _H_         _H_ \
                       UUU         UUU         UUU
__EOF__

echo
echo "******************************************************************************"
echo "***** Sandfly Automated Single-VM Setup **************************************"
echo "******************************************************************************"
echo
echo "Please press ENTER to view the Sandfly License Agreement."
read PAUSE
less --quit-at-eof ../LICENSE.txt
echo "Do you agree to the terms of the Sandfly License Agreement?"
echo -n "Type YES if so ===> "
read LIC_AGREE
LIC_AGREE=$(echo $LIC_AGREE | tr '[:upper:]' '[:lower:]')
if [ "$LIC_AGREE" != "yes" ]; then
    echo; echo "Response was not \"yes\"; quitting setup."
    exit 1
fi

$SUDO docker version > /dev/null 2>&1 || \
    { echo; echo "*** ERROR: Unable to run docker as current user or via sudo."; exit 1; }

### Run initial setup
EXTERNALIP=$(dig @ns1.google.com -4 TXT o-o.myaddr.l.google.com +short | tr -d \")
if [ $? -ne 0 ]; then
    echo "*** ERROR: Unable to get external IP"
    exit 1
fi

### Need to determine if the external IP is directly assigned to an interface
if [ ! $(ip addr | grep $EXTERNALIP) ]; then
    INTERNALIFACE=$(ls /sys/class/net|egrep '^e'|head -n 1)
    INTERNALIP=$(ip address show dev ${INTERNALIFACE}|grep "inet " | awk '{print $2}' | awk -F/ '{print $1}'|head -n 1)
else
    INTERNALIP=$EXTERNALIP
fi

# Make this an all-in-one server
if [ $EUID -ne 0 ]; then
    sudo touch setup_data/allinone
else
    touch setup_data/allinone
fi

echo
echo "******************************************************************************"
echo "Running Sandfly initial configuration script. This will take about 60 seconds."
echo "(Logging to /tmp/sandfly-install-log)"
echo "******************************************************************************"
echo
$SUDO env SANDFLY_SETUP_AUTO_HOSTNAME=$INTERNALIP ./install.sh 2>&1 | tee /tmp/sandfly-install-log
if [ $? -ne 0 ]; then
    echo "*** ERROR: Error running install.sh script."
    exit 2
fi

echo
echo "******************************************************************************"
echo "Waiting for RabbitMQ to configure and start. This will take about 60"
echo "seconds."
echo "******************************************************************************"
echo
cd ../start_scripts
$SUDO ./start_rabbit.sh >/dev/null 2>&1
# Wait a maximum of 2 minutes, double what we should need
TIMER=120
while true; do
    docker logs sandfly-rabbit 2>&1 | grep "Server startup complete" > /dev/null
    if [ $? -eq 0 ]; then
        echo
        break
    fi
    TIMER=$(expr $TIMER - 5)
    if [ $TIMER -le 0 ]; then
        echo "*** ERROR: the sandfly-rabbit container took too long to configure and start."
        echo "*** Automatic setup could not complete."
        exit 2
    fi
    echo -n "."
    sleep 5
done

echo
echo "******************************************************************************"
echo "Waiting for Sandfly Server to configure and start. This will take about"
echo "20 seconds."
echo "******************************************************************************"
echo
$SUDO ./start_server.sh >/dev/null 2>&1
# Wait a maximum of 2 minutes, double what we should need
TIMER=120
while true; do
    docker logs sandfly-server 2>&1 | grep "Starting Sandfly API service version" > /dev/null
    if [ $? -eq 0 ]; then
        echo
        break
    fi
    TIMER=$(expr $TIMER - 5)
    if [ $TIMER -le 0 ]; then
        echo "*** ERROR: the sandfly-server container took too long start."
        echo "*** Automatic setup could not complete."
        exit 2
    fi
    echo -n "."
    sleep 5
done

echo
echo "******************************************************************************"
echo "Starting Sandfly Scanning nodes."
echo "******************************************************************************"
echo
$SUDO ./start_node.sh >/dev/null 2>&1
$SUDO ./start_node.sh >/dev/null 2>&1

echo
echo "******************************************************************************"
echo "Acquiring and installing free edition license key."
echo "******************************************************************************"
echo

cd ../setup/setup_scripts
$SUDO ./setup_demo_license.sh
if [ $? -ne 0 ]; then
    echo
    echo "*** ERROR: unable to auto-install license key. For a free license,"
    echo "***        please go to www.sandflysecurity.com and request a free license."
    echo
fi

cd ..

echo
echo
echo "******************************************************************************"
echo "**                                                                          **"
echo "** SANDFLY INSTALLATION COMPLETE                                            **"
echo "**                                                                          **"
echo "** Use the URL and login information printed below to log in to your        **"
echo "** server. The initial admin password is stored on this server in           **"
echo "** the setup_data directory; we recommend you change your initial           **"
echo "** password after logging in.                                               **"
echo "**                                                                          **"
echo "******************************************************************************"
echo
echo "===> URL: https://$EXTERNALIP/"
echo "===> Username: admin"
echo "===> Password: $(cat setup_data/admin.password.txt)"
echo
echo " ** Make sure ports 80 and 443 are open in the firewall! **"
echo
