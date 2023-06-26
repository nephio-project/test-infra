#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2023 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o pipefail
set -o errexit
set -o nounset

# get_status() - Print the current status of the management cluster
function get_status {
    set +o xtrace
    if [ -f /proc/stat ]; then
        printf "CPU usage: "
        grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage " %"}'
    fi
    if [ -f /proc/pressure/io ]; then
        printf "I/O Pressure Stall Information (PSI): "
        grep full /proc/pressure/io | awk '{ sub(/avg300=/, ""); print $4 }'
    fi
    if [ -f /proc/zoneinfo ]; then
        printf "Memory free(Kb):"
        awk -v low="$(grep low /proc/zoneinfo | awk '{k+=$2}END{print k}')" '{a[$1]=$2}  END{ print a["MemFree:"]+a["Active(file):"]+a["Inactive(file):"]+a["SReclaimable:"]-(12*low);}' /proc/meminfo
    fi
    if command -v kubectl >/dev/null; then
        echo "Kubernetes Events:"
        kubectl get events
        echo "Kubernetes Resources:"
        kubectl get all -A -o wide
    fi
}

function get_metadata {
    local md=$1
    local df=$2

    curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$md" -H "Metadata-Flavor: Google" || echo "$df"
}

export DEBUG=${NEPHIO_DEBUG:-$(get_metadata nephio-setup-debug "false")}

[[ $DEBUG != "true" ]] || set -o xtrace

DEPLOYMENT_TYPE=${NEPHIO_DEPLOYMENT_TYPE:-$(get_metadata nephio-setup-type "r1")}
RUN_E2E=${NEPHIO_RUN_E2E:-$(get_metadata nephio-run-e2e "false")}
REPO=${NEPHIO_REPO:-$(get_metadata nephio-test-infra-repo "https://github.com/nephio-project/test-infra.git")}
BRANCH=${NEPHIO_BRANCH:-$(get_metadata nephio-test-infra-branch "main")}
NEPHIO_USER=${NEPHIO_USER:-$(get_metadata nephio-user "ubuntu")}
HOME=${NEPHIO_HOME:-/home/$NEPHIO_USER}
REPO_DIR=${NEPHIO_REPO_DIR:-$HOME/test-infra}

echo "$DEBUG, $DEPLOYMENT_TYPE, $RUN_E2E, $REPO, $BRANCH, $NEPHIO_USER, $HOME, $REPO_DIR"
trap get_status ERR

if ! command -v git >/dev/null; then
    apt-get update
    apt-get install -y git
fi

if [ ! -d "$REPO_DIR" ]; then
    runuser -u "$NEPHIO_USER" git clone "$REPO" "$REPO_DIR"
    if [[ $BRANCH != "main" ]]; then
        pushd "$REPO_DIR" >/dev/null
        runuser -u "$NEPHIO_USER" -- git checkout -b "$BRANCH" --track "origin/$BRANCH"
        popd >/dev/null
    fi
fi
find "$REPO_DIR" -name '*.sh' -exec chmod +x {} \;

cp "$REPO_DIR/e2e/provision/bash_config.sh" "$HOME/.bash_aliases"
chown "$NEPHIO_USER:$NEPHIO_USER" "$HOME/.bash_aliases"

sed -e "s/vagrant/$NEPHIO_USER/" <"$REPO_DIR/e2e/provision/nephio.yaml" >"$HOME/nephio.yaml"

cd "$REPO_DIR/e2e/provision"
export DEBUG DEPLOYMENT_TYPE
runuser -u "$NEPHIO_USER" ./install_sandbox.sh

# Grant Docker permissions to current user
if ! getent group docker | grep -q "$NEPHIO_USER"; then
    sudo usermod -aG docker "$NEPHIO_USER"
fi

if [[ $RUN_E2E == "true" ]]; then
    runuser -u "$NEPHIO_USER" "$REPO_DIR/e2e/e2e.sh"
fi
