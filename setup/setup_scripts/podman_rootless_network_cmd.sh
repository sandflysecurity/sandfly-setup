#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# configure 'pasta' as the default_rootless_network_cmd

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Verify or Set CONTAINERMGR variable
if [ -z "${CONTAINERMGR}" ]; then
    . ./container_command.sh
    if [ $? -ne 0 ]; then
        # Failed to find container runtime. The container_command script will
        # have printed an error.
        exit 1
    fi
fi

# Are we using Podman?
if [ ! "$CONTAINERMGR" = "podman" ]; then
    exit 0
fi

# Are we running as root?
if [ $(id -u) -eq 0 ]; then
    exit 0
fi

# Check if Podman is version 5 or later
podman_major_version=$(podman version -f '{{index (split .Client.Version ".") 0}}' 2>/dev/null)
if [ -z "${podman_major_version}" ]; then
    echo "ERROR: unable to determine Podman major version."
    exit 1
fi

if [ "${podman_major_version:-0}" -lt 5 ]; then
    exit 0
fi

# Make sure the user containers folder exists
mkdir -p ~/.config/containers

containers_conf=~/.config/containers/containers.conf

# Records that the user declined to switch to pasta, so we don't ask again.
# Delete this file to be asked again.
SETUP_DATA=../setup_data
DECLINED_FILE=${SETUP_DATA}/podman_pasta.declined

podman_network=$(podman info --format='{{.Host.RootlessNetworkCmd}}' 2>/dev/null)
echo "Podman rootless network cmd : $podman_network"
if [ "$podman_network" == "pasta" ]; then
    rm -f ${DECLINED_FILE}
    exit 0
fi

if [ -f ${containers_conf} ]; then
    if [ -f ${DECLINED_FILE} ]; then
        echo "INFO: Keeping ${podman_network} as the rootlessNetworkCmd (IPv6 disabled)."
        echo "  Delete $(realpath ${DECLINED_FILE}) to be asked again."
        exit 0
    fi

    # Without a terminal we can't ask, so keep the current setting and
    # don't record a decision the user never made.
    if [ ! -t 0 ]; then
        echo "INFO: Keeping ${podman_network} as the rootlessNetworkCmd (no terminal to prompt)."
        exit 0
    fi

    echo ""
    echo "WARNING: The file [${containers_conf}] already exists."
    echo "Modify the file with pasta as the rootlessNetworkCmd? IPv6 networking"
    echo "for Sandfly containers requires pasta when running rootless Podman."
    echo "If you decline, you will not be asked again."
    read -p "Type YES to use pasta, press <Return> to continue with ${podman_network}: " CONF_RESPONSE
    case "${CONF_RESPONSE}" in
        [Yy]|[Yy][Ee][Ss])
            ;;
        *)
            # continue with existing rootless network cmd per user request
            mkdir -p ${SETUP_DATA}
            echo "${podman_network} $(date +%Y-%m-%dT%H:%M:%S%z)" > ${DECLINED_FILE}
            exit 0
            ;;
    esac
fi

# Verify the pasta command exists
if ! command -v pasta >/dev/null 2>&1; then
    echo ""
    echo "********************************** ERROR **********************************"
    echo "*                                                                         *"
    echo "* pasta is required for networking when using rootless Podman.            *"
    echo "*                                                                         *"
    echo "* Please install the pasta package (e.g. 'dnf install passt')             *"
    echo "* and try again.                                                          *"
    echo "*                                                                         *"
    echo "********************************** ERROR **********************************"
    echo ""
    exit 1
fi

# Modify or create the containers.conf file with pasta as default_rootless_network_cmd
if [ -f ${containers_conf} ]; then
    # Save a copy of the original containers.conf file
    BAKTIMESTAMP=$(date +%Y%m%d_%H%M%S)
    cp -f -p ${containers_conf} ${containers_conf}.bak_${BAKTIMESTAMP}

    # Remove any previously configured default_rootless_network_cmd entries:
    sed -i '/^default_rootless_network_cmd/d' ${containers_conf}

    # Make sure we have a [network] stanza in the containers.conf file
    t_network=$(grep "^\[network\]" ${containers_conf} | wc -l)
    if [ $t_network -eq 0 ]; then
        echo "[network]" >> ${containers_conf}
    fi

    # Configure pasta as default_rootless_network_cmd
    t_count=$(grep "^#default_rootless_network_cmd =" ${containers_conf} | wc -l)
    if [ $t_count -ge 1 ]; then
        sed -i '/^#default_rootless_network_cmd/a default_rootless_network_cmd = "pasta"' ${containers_conf}
    else
        sed -i '/^\[network\]/a default_rootless_network_cmd = "pasta"' ${containers_conf}
    fi
else
    # Create the containers.conf file with [network] stanza
    echo "[network]" > ${containers_conf}
    sed -i '/^\[network\]/a default_rootless_network_cmd = "pasta"' ${containers_conf}
fi

# Double check that pasta is configured
t_verify_network=$(podman info --format='{{.Host.RootlessNetworkCmd}}' 2>/dev/null)
echo "Podman rootless network cmd : $t_verify_network"
if [ ! "$t_verify_network" == "pasta" ]; then
    echo ""
    echo "ERROR: must use pasta as rootlessNetworkCmd"
    echo ""
    exit 1
fi

exit 0
