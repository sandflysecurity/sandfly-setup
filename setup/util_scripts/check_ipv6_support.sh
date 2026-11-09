#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# Checks whether this system can give the 'sandfly-net' container network
# IPv6 support. It reports each host and container runtime setting the
# installer relies on, then a final result.
#
# The required checks mirror the ones setup_scripts/create_sandfly_net.sh
# makes, so a SUPPORTED result here means the installer will create
# 'sandfly-net' with IPv6. Checks marked WARN don't stop IPv6 from being
# enabled but may stop it from working.
#
# Exit status: 0 if IPv6 can be supported, 1 if not.
#
# The container runtime is chosen the same way as the installer: podman if
# installed, otherwise docker. Set CONTAINERMGR=docker or CONTAINERMGR=podman
# to check a specific one.

# Make sure we run from the correct directory so relative paths work
cd "$( dirname "${BASH_SOURCE[0]}" )"

SETUP_DATA=../setup_data

if [ -t 1 ]; then
    C_PASS=$'\e[32m'; C_FAIL=$'\e[31m'; C_WARN=$'\e[33m'; C_INFO=$'\e[36m'; C_OFF=$'\e[0m'
else
    C_PASS=""; C_FAIL=""; C_WARN=""; C_INFO=""; C_OFF=""
fi

FAILURES=0
WARNINGS=0

# Print one result line: <status> <setting> <current value> [detail]
report() {
    local t_status=$1 t_setting=$2 t_value=$3 t_detail=$4 t_color

    case "${t_status}" in
        PASS) t_color=${C_PASS} ;;
        FAIL) t_color=${C_FAIL}; FAILURES=$((FAILURES + 1)) ;;
        WARN) t_color=${C_WARN}; WARNINGS=$((WARNINGS + 1)) ;;
        *)    t_color=${C_INFO} ;;
    esac

    printf "  [%s%-4s%s] %-44s %s\n" "${t_color}" "${t_status}" "${C_OFF}" "${t_setting}" "${t_value}"
    if [ -n "${t_detail}" ]; then
        printf "         %s\n" "${t_detail}"
    fi
}

section() {
    echo ""
    echo "$1"
    echo "$1" | sed 's/./-/g'
}

# Print a sysctl value read from /proc, or nothing if it can't be read.
read_sysctl() {
    local t_file=/proc/sys/${1//.//}
    [ -r "${t_file}" ] && tr -d '[:space:]' < "${t_file}"
}

###############################################################################
# Host
###############################################################################

section "Host IPv6 settings"

HOST_IPV6=yes

if [ -d /proc/sys/net/ipv6 ]; then
    report PASS "IPv6 kernel support" "loaded"
else
    HOST_IPV6=no
    if grep -qw 'ipv6.disable=1' /proc/cmdline 2>/dev/null; then
        report FAIL "IPv6 kernel support" "disabled" \
            "The kernel was booted with ipv6.disable=1. Remove it from the boot parameters and reboot."
    else
        report FAIL "IPv6 kernel support" "not loaded" \
            "/proc/sys/net/ipv6 is missing. Load the ipv6 module or use a kernel with IPv6 support."
    fi
fi

for t_scope in default all; do
    t_setting=net.ipv6.conf.${t_scope}.disable_ipv6
    t_value=$(read_sysctl ${t_setting})

    if [ -z "${t_value}" ]; then
        HOST_IPV6=no
        report FAIL "${t_setting}" "unreadable" \
            "The setting could not be read, so the installer treats IPv6 as disabled."
    elif [ "${t_value}" = "0" ]; then
        report PASS "${t_setting}" "${t_value}"
    else
        HOST_IPV6=no
        report FAIL "${t_setting}" "${t_value}" \
            "Must be 0. Set '${t_setting} = 0' in /etc/sysctl.d/ and run 'sudo sysctl --system'."
    fi
done

# The checks below don't affect whether the installer enables IPv6, only
# whether IPv6 traffic from the containers can actually leave this host.
if [ "${HOST_IPV6}" = "yes" ] && command -v ip >/dev/null 2>&1; then
    t_global=$(ip -6 addr show scope global 2>/dev/null | awk '/inet6/ {print $2; exit}')
    if [ -n "${t_global}" ]; then
        report PASS "Global IPv6 address" "${t_global}"
    else
        report WARN "Global IPv6 address" "none" \
            "Containers will get IPv6 addresses but cannot reach IPv6 hosts outside this system."
    fi

    t_route=$(ip -6 route show default 2>/dev/null | head -n 1)
    if [ -n "${t_route}" ]; then
        t_dev=$(echo "${t_route}" | awk '{for (i = 1; i < NF; i++) if ($i == "dev") print $(i + 1)}')
        t_proto=$(echo "${t_route}" | awk '{for (i = 1; i < NF; i++) if ($i == "proto") print $(i + 1)}')
        report PASS "IPv6 default route" "via ${t_dev:-unknown}${t_proto:+ (${t_proto})}"

        # Docker and Podman turn on IPv6 forwarding when they create an IPv6
        # network. With forwarding on, the kernel stops accepting router
        # advertisements on an interface whose accept_ra is 1, so a default
        # route learned that way disappears when it expires. accept_ra=0
        # means NetworkManager or systemd-networkd handle router
        # advertisements themselves, which forwarding doesn't affect.
        if [ "${t_proto}" = "ra" ] && [ -n "${t_dev}" ]; then
            t_accept_ra=$(read_sysctl net.ipv6.conf.${t_dev}.accept_ra)
            if [ "${t_accept_ra}" = "1" ]; then
                report WARN "net.ipv6.conf.${t_dev}.accept_ra" "${t_accept_ra}" \
                    "Set to 2 so the default route survives IPv6 forwarding being turned on."
            else
                report PASS "net.ipv6.conf.${t_dev}.accept_ra" "${t_accept_ra:-unreadable}"
            fi
        fi
    else
        report WARN "IPv6 default route" "none" \
            "Containers cannot reach IPv6 hosts outside the local network."
    fi
fi

###############################################################################
# Container runtime
###############################################################################

if [ -z "${CONTAINERMGR}" ]; then
    if command -v podman >/dev/null 2>&1; then
        CONTAINERMGR=podman
    elif command -v docker >/dev/null 2>&1; then
        CONTAINERMGR=docker
    fi
fi

RUNTIME_IPV6=no

case "${CONTAINERMGR}" in
docker)
    section "Docker"

    docker_version=$(docker version -f '{{.Server.Version}}' 2>/dev/null)
    docker_major_version=${docker_version%%.*}
    case "${docker_major_version}" in
        ''|*[!0-9]*) docker_major_version="" ;;
    esac

    if [ -z "${docker_major_version}" ]; then
        report FAIL "Docker server version" "unknown" \
            "Could not reach the Docker daemon. Run as root or as a user in the docker group."
    elif [ "${docker_major_version}" -ge 27 ]; then
        report PASS "Docker server version" "${docker_version}" \
            "Docker 27 or later needs no daemon configuration for IPv6."
        RUNTIME_IPV6=yes
    elif [ "${docker_major_version}" -ge 20 ]; then
        report PASS "Docker server version" "${docker_version}" \
            "Docker 20.10 to 26 need 'experimental' and 'ip6tables' enabled."

        # Rootless Docker reads a per-user file instead of the system one.
        DOCKER_DAEMON_JSON=/etc/docker/daemon.json
        if [ -f "${HOME}/.config/docker/daemon.json" ]; then
            DOCKER_DAEMON_JSON="${HOME}/.config/docker/daemon.json"
        fi

        if [ -f "${DOCKER_DAEMON_JSON}" ]; then
            report INFO "Daemon configuration file" "${DOCKER_DAEMON_JSON}"
        else
            report FAIL "Daemon configuration file" "missing" \
                "Create ${DOCKER_DAEMON_JSON} with \"experimental\": true and \"ip6tables\": true."
        fi

        RUNTIME_IPV6=yes
        for t_key in experimental ip6tables; do
            # Same parsing as create_sandfly_net.sh: strip all whitespace,
            # then find the top-level boolean.
            t_value=""
            if [ -f "${DOCKER_DAEMON_JSON}" ]; then
                t_value=$(tr -d '[:space:]' < "${DOCKER_DAEMON_JSON}" \
                    | grep -Eo "\"${t_key}\":(true|false)" | head -n 1 | cut -d: -f2)
            fi

            if [ "${t_value}" = "true" ]; then
                report PASS "daemon.json \"${t_key}\"" "true"
            else
                RUNTIME_IPV6=no
                report FAIL "daemon.json \"${t_key}\"" "${t_value:-not set}" \
                    "Must be true. Restart Docker after editing the file."
            fi
        done
    else
        report FAIL "Docker server version" "${docker_version}" \
            "Docker 20.10 or later is required for IPv6 on a user-defined network."
    fi

    if [ "${RUNTIME_IPV6}" = "yes" ] && ! command -v ip6tables >/dev/null 2>&1; then
        report WARN "ip6tables command" "not found" \
            "Docker uses ip6tables for IPv6 NAT. Install the iptables package if IPv6 connections fail."
    fi

    if docker compose version >/dev/null 2>&1; then
        report INFO "Docker Compose" "$(docker compose version --short 2>/dev/null)"
    fi
    ;;
podman)
    section "Podman"

    podman_version=$(podman version -f '{{.Client.Version}}' 2>/dev/null)
    podman_major_version=${podman_version%%.*}
    case "${podman_major_version}" in
        ''|*[!0-9]*) podman_major_version="" ;;
    esac

    if [ -z "${podman_major_version}" ]; then
        report FAIL "Podman version" "unknown" "Could not run 'podman version'."
    elif [ "${podman_major_version}" -lt 5 ]; then
        report FAIL "Podman version" "${podman_version}" \
            "Podman 5 or later is required for IPv6."
    else
        report PASS "Podman version" "${podman_version}"

        if [ $(id -u) -eq 0 ]; then
            report PASS "Podman mode" "root"
            RUNTIME_IPV6=yes
        else
            report INFO "Podman mode" "rootless"

            podman_network=$(podman info --format='{{.Host.RootlessNetworkCmd}}' 2>/dev/null)
            if [ "${podman_network}" = "pasta" ]; then
                report PASS "Rootless network command" "pasta"
                RUNTIME_IPV6=yes
            else
                if command -v pasta >/dev/null 2>&1; then
                    t_detail="pasta is installed. Run start_sandfly.sh or set default_rootless_network_cmd = \"pasta\" in ~/.config/containers/containers.conf."
                else
                    t_detail="Install the passt package, then set default_rootless_network_cmd = \"pasta\" in ~/.config/containers/containers.conf."
                fi
                report FAIL "Rootless network command" "${podman_network:-unknown}" "${t_detail}"

                if [ -f "${SETUP_DATA}/podman_pasta.declined" ]; then
                    report INFO "Switch to pasta previously declined" "yes" \
                        "Delete $(realpath ${SETUP_DATA}/podman_pasta.declined) to be asked again."
                fi
            fi
        fi
    fi
    ;;
*)
    section "Container runtime"
    report FAIL "Docker or Podman" "not found" "Install Docker or Podman and run this check again."
    ;;
esac

# An existing network is never changed by the installer, so report whether
# it already has IPv6.
if [ "${CONTAINERMGR}" = "docker" ] || [ "${CONTAINERMGR}" = "podman" ]; then
    if [ "${CONTAINERMGR}" = "docker" ]; then
        t_subnets=$(docker network inspect sandfly-net --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null)
    else
        t_subnets=$(podman network inspect sandfly-net --format '{{range .Subnets}}{{.Subnet}} {{end}}' 2>/dev/null)
    fi

    if [ $? -ne 0 ]; then
        report INFO "Existing 'sandfly-net' network" "none" \
            "It will be created at install or start time."
    elif [[ "${t_subnets}" == *:* ]]; then
        report PASS "Existing 'sandfly-net' network" "${t_subnets% }"
    else
        report WARN "Existing 'sandfly-net' network" "${t_subnets% } (IPv4 only)" \
            "Stop the Sandfly containers and run '${CONTAINERMGR} network rm sandfly-net' to recreate it with IPv6."
    fi
fi

###############################################################################
# Result
###############################################################################

echo ""
if [ "${HOST_IPV6}" = "yes" ] && [ "${RUNTIME_IPV6}" = "yes" ]; then
    if [ ${WARNINGS} -gt 0 ]; then
        echo "${C_PASS}RESULT: IPv6 is SUPPORTED on this system${C_OFF} (${WARNINGS} warning(s) above)."
    else
        echo "${C_PASS}RESULT: IPv6 is SUPPORTED on this system.${C_OFF}"
    fi
    echo ""
    exit 0
fi

echo "${C_FAIL}RESULT: IPv6 is NOT SUPPORTED on this system${C_OFF} (${FAILURES} failed check(s) above)."
echo "  Sandfly will run with IPv4 only."
echo ""
exit 1
