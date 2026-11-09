#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# create 'sandfly-net' network with correct IPv6 parameters

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

# Docker's daemon configuration file. Rootless Docker reads a per-user file
# instead of the system one.
DOCKER_DAEMON_JSON=/etc/docker/daemon.json
if [ -f "${HOME}/.config/docker/daemon.json" ]; then
    DOCKER_DAEMON_JSON="${HOME}/.config/docker/daemon.json"
fi

# Print the value of a top-level boolean in the Docker daemon configuration
# file ("true" or "false"), or nothing when the file or the key is absent.
# All whitespace is stripped first so the key, colon and value may be spread
# over any number of lines.
docker_daemon_bool() {
    [ -f "${DOCKER_DAEMON_JSON}" ] || return 0
    tr -d '[:space:]' < "${DOCKER_DAEMON_JSON}" \
        | grep -Eo "\"$1\":(true|false)" \
        | head -n 1 \
        | cut -d: -f2
}

# Will IPv6 actually work for our containers on this host? The presence of
# /proc/sys/net/ipv6 only tells us the ipv6 module is loaded; IPv6 can still be
# switched off administratively, so we also check both disable_ipv6 sysctls,
# either of which breaks IPv6 for us:
#
#   conf.default - what any newly created interface in the host namespace
#                  inherits, and that includes 'sandfly-net's bridge and the
#                  host end of every container's veth pair. With it set, those
#                  come up with IPv6 disabled and cannot carry the container's
#                  IPv6 traffic.
#   conf.all     - the host's existing interfaces, including the uplink that
#                  traffic has to leave by.
#
# Neither value reaches the container's own network namespace: the kernel
# resets disable_ipv6 for a new namespace from the boot-time ipv6.disable
# parameter rather than from the running host's sysctls. These checks therefore
# describe the host side of the path, not the container's.
#
# Anything we cannot read counts as "not enabled". Creating 'sandfly-net'
# without IPv6 only costs us the feature, whereas asking for an IPv6 subnet on
# a host that cannot provide one stops the network from being created at all.
host_has_ipv6() {
    [ -d /proc/sys/net/ipv6 ] || return 1

    for t_scope in default all; do
        t_disable=/proc/sys/net/ipv6/conf/${t_scope}/disable_ipv6

        [ -r "${t_disable}" ] || return 1
        [ "$(tr -d '[:space:]' < "${t_disable}")" = "0" ] || return 1
    done

    return 0
}

if ${CONTAINERMGR} network inspect sandfly-net > /dev/null 2>&1; then
    echo "Network 'sandfly-net' already exists:"
    if [ "${CONTAINERMGR}" = "docker" ]; then
        ${CONTAINERMGR} network inspect sandfly-net --format '{{range .IPAM.Config}}Subnet: {{.Subnet}} Gateway: {{.Gateway}}{{println}}{{end}}'
    elif [ "${CONTAINERMGR}" = "podman" ]; then
        ${CONTAINERMGR} network inspect sandfly-net --format '{{range .Subnets}}Subnet: {{.Subnet}} Gateway: {{.Gateway}}{{println}}{{end}}'
    fi
    exit 0
fi

IPV6FLAGS=""

if host_has_ipv6; then
    IPV6NET="fd5f:a11d:f1ff::"

    if [ "${CONTAINERMGR}" = "docker" ]; then
        docker_major_version=$(docker version -f '{{index (split .Server.Version ".") 0}}' 2>/dev/null)
        # Ignore anything that isn't a plain number (e.g. an unreachable daemon).
        case "${docker_major_version}" in
            ''|*[!0-9]*) docker_major_version="" ;;
        esac

        if [ -z "${docker_major_version}" ]; then
            echo "WARNING: Unable to determine the Docker server version."
            echo "  Creating 'sandfly-net' without IPv6 support."
        elif [ "${docker_major_version}" -ge 27 ]; then
            # Docker 27 and later: ip6tables (IPv6 network isolation and NAT)
            # is enabled by default and --ipv6 allocates a ULA subnet itself.
            IPV6FLAGS="--ipv6"
        elif [ "${docker_major_version}" -ge 20 ]; then
            # Docker 20.10 through 26: --ipv6 requires an explicit subnet, and
            # ip6tables is experimental and off by default. Without ip6tables
            # a container gets an address on our ULA subnet but no NAT, so the
            # node looks IPv6-capable while every IPv6 connection fails -
            # worse than having no IPv6 at all. Require both daemon options.
            #
            # Note: "ipv6" and "fixed-cidr-v6" configure only the default
            # docker0 bridge; neither is needed for a user-defined network.
            if [ "$(docker_daemon_bool experimental)" = "true" ] && \
               [ "$(docker_daemon_bool ip6tables)" = "true" ]; then
                IPV6FLAGS="--ipv6 --subnet ${IPV6NET}/64 --gateway ${IPV6NET}1"
            else
                echo "INFO: IPv6 is not enabled in the Docker ${docker_major_version} daemon configuration."
                echo "  Creating 'sandfly-net' without IPv6 support."
            fi
        else
            echo "INFO: Docker ${docker_major_version} is too old to support IPv6 on a user-defined"
            echo "  network. Creating 'sandfly-net' without IPv6 support."
        fi
    elif [ "${CONTAINERMGR}" = "podman" ]; then
        podman_major_version=$(podman version -f '{{index (split .Client.Version ".") 0}}' 2>/dev/null)
        if [ "${podman_major_version:-0}" -gt 4 ]; then
            if [ $(id -u) -eq 0 ]; then
                IPV6FLAGS="--ipv6"
            else
                podman_network=$(podman info --format='{{.Host.RootlessNetworkCmd}}' 2>/dev/null)
                echo "Podman rootless network cmd : $podman_network"
                if [ "$podman_network" == "pasta" ]; then
                    IPV6FLAGS="--ipv6"
                fi
            fi
        fi
        # Podman version 4.x not supported for IPV6
    fi
fi

CREATE_OUTPUT=$(${CONTAINERMGR} network create ${IPV6FLAGS} sandfly-net 2>&1)

if [ $? -ne 0 ]; then
    if [ -z "${IPV6FLAGS}" ]; then
        echo "ERROR: Failed to create network sandfly-net"
        echo "  Error Message: ${CREATE_OUTPUT}"
        exit 1
    fi

    echo "WARNING: Failed to create network sandfly-net ${IPV6FLAGS}"
    echo "  Error Message: ${CREATE_OUTPUT}"

    # Try creating the network without the IPv6 flags
    CREATE_OUTPUT=$(${CONTAINERMGR} network create sandfly-net 2>&1)

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create network sandfly-net"
        echo "  Error Message: ${CREATE_OUTPUT}"
        exit 1
    fi
fi

echo "Network 'sandfly-net' created successfully"

if [ "${CONTAINERMGR}" = "docker" ]; then
    ${CONTAINERMGR} network inspect sandfly-net --format '{{range .IPAM.Config}}Subnet: {{.Subnet}} Gateway: {{.Gateway}}{{println}}{{end}}'
elif [ "${CONTAINERMGR}" = "podman" ]; then
    ${CONTAINERMGR} network inspect sandfly-net --format '{{range .Subnets}}Subnet: {{.Subnet}} Gateway: {{.Gateway}}{{println}}{{end}}'
fi

exit 0
