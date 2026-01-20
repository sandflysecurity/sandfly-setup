#!/usr/bin/env sh
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) Sandfly Security LTD, All Rights Reserved.

# exports CONTAINERMGR variable -- "podman" or "docker". Displays info to
# stdout if an acceptable command isn't found and returns non-0.
#
# This script should be sourced from other scripts.

# If podman is available, assume the user prefers that. We support root or
# rootless podman, so no further check is needed.
if command -v podman > /dev/null 2>&1 ; then
    CONTAINERMGR=podman
    export CONTAINERMGR
    return 0 2>/dev/null || exit 0
fi

# Check that there isn't a snap-installed Docker
if [ -f "/snap/bin/docker" ]; then
    echo ""
    echo "****************************** ERROR ******************************"
    echo "*                                                                 *"
    echo "* A version of Docker appears to be installed via Snap.           *"
    echo "*                                                                 *"
    echo "* Sandfly is only compatible with the apt version of Docker.      *"
    echo "* Having both versions installed will conflict with Sandfly.      *"
    echo "* Please remove the snap version before installing Sandfly.       *"
    echo "*                                                                 *"
    echo "****************************** ERROR ******************************"
    echo ""
    return 1 2>/dev/null || exit 0
fi

if ! command -v docker > /dev/null 2>&1 ; then
    echo ""
    echo "****************************** ERROR ******************************"
    echo "* No docker or podman command found; please install Docker or     *"
    echo "* Podman and try again.                                           *"
    echo "****************************** ERROR ******************************"
    echo ""
    return 1 2>/dev/null || exit 0
fi

# At this point, we know we don't have podman but we do have docker. Test
# that we can run docker.
if ! docker version > /dev/null 2>&1 ; then
    echo ""
    echo "****************************** ERROR ******************************"
    echo "* Unable to run the docker command. This script must be run as    *"
    echo "* root or as a user with access to the Docker daemon.             *"
    echo "****************************** ERROR ******************************"
    echo ""
    return 1 2>/dev/null || exit 0
fi

# Docker is okay.
CONTAINERMGR=docker
export CONTAINERMGR
