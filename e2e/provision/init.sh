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
    printf "Disk usage: "
    sudo df -h
    if command -v docker >/dev/null; then
        echo "Docker statistics:"
        docker stats --no-stream
        docker ps --size
    fi
    if [ -f /tmp/e2e_dmesg_base.log ]; then
        echo "Kernel diagnostic messages:"
        sudo dmesg >/tmp/e2e_dmesg_current.log
        diff /tmp/e2e_dmesg_base.log /tmp/e2e_dmesg_current.log
    fi
    if command -v kubectl >/dev/null; then
        echo "Draft Porch Package Revisions"
        kubectl get packagerevision -o jsonpath='{range .items[?(@.spec.lifecycle=="Draft")]}{.metadata.name}{"\n"}{end}' || :
        KUBECONFIG=$HOME/.kube/config
        for kubeconfig in /tmp/*-kubeconfig; do
            KUBECONFIG+=":$kubeconfig"
        done
        export KUBECONFIG
        for context in $(kubectl config get-contexts --no-headers --output name); do
            echo "Kubernetes Events ($context):"
            kubectl get events --sort-by='.lastTimestamp' -A --context "$context" --field-selector type!=Normal
            echo "Kubernetes Resources ($context):"
            kubectl get all -A -o wide --context "$context"
        done
    fi
}

function get_metadata {
    local md=$1
    local df=$2

    curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$md" -H "Metadata-Flavor: Google" || echo "$df"
}

export DEBUG=${NEPHIO_DEBUG:-$(get_metadata nephio-setup-debug "false")}

[[ $DEBUG != "true" ]] || set -o xtrace

RUN_E2E=${NEPHIO_RUN_E2E:-$(get_metadata nephio-run-e2e "false")}
REPO=${NEPHIO_REPO:-$(get_metadata nephio-test-infra-repo "https://github.com/nephio-project/test-infra.git")}
BRANCH=${NEPHIO_BRANCH:-$(get_metadata nephio-test-infra-branch "main")}
NEPHIO_USER=${NEPHIO_USER:-$(get_metadata nephio-user "${USER:-ubuntu}")}
NEPHIO_CATALOG_REPO_URI=${NEPHIO_CATALOG_REPO_URI:-$(get_metadata nephio-catalog-repo-uri "https://github.com/nephio-project/catalog.git")}
K8S_CONTEXT=${K8S_CONTEXT:-"kind-kind"}
K8S_VERSION=${K8S_VERSION:-"v1.29.2"}
export ANSIBLE_CMD_EXTRA_VAR_LIST='{ "nephio_catalog_repo_uri": "'${NEPHIO_CATALOG_REPO_URI}'", "k8s": { "context" : "'${K8S_CONTEXT}'", "version" : "'$K8S_VERSION'" } }'
HOME=${NEPHIO_HOME:-/home/$NEPHIO_USER}
REPO_DIR=${NEPHIO_REPO_DIR:-$HOME/test-infra}
DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME:-""}
DOCKERHUB_TOKEN=${DOCKERHUB_TOKEN:-""}
FAIL_FAST=${FAIL_FAST:-$(get_metadata fail_fast "false")}

if [ ${K8S_CONTEXT} == "kind-kind" ]; then
    export ANSIBLE_TAG=all
else
    export ANSIBLE_TAG=nonkind_k8s
fi

echo "$DEBUG, $RUN_E2E, $REPO, $BRANCH, $NEPHIO_USER, $HOME, $REPO_DIR, $DOCKERHUB_USERNAME, $DOCKERHUB_TOKEN, $ANSIBLE_TAG, $ANSIBLE_CMD_EXTRA_VAR_LIST"
trap get_status ERR

# Validate root permissions for current user and NEPHIO_USER
if ! sudo -n "true"; then
    echo ""
    echo "Passwordless sudo is needed for '$(id -nu)' user."
    echo "Please fix your /etc/sudoers file. You likely want an"
    echo "entry like the following one..."
    echo ""
    echo "$(id -nu) ALL=(ALL) NOPASSWD: ALL"
    exit 1
fi

if ! sudo -u "$NEPHIO_USER" sudo -n "true"; then
    echo ""
    echo "Passwordless sudo is needed for '$(sudo -u "$NEPHIO_USER" id -nu)' user."
    echo "Please fix your /etc/sudoers file. You likely want an"
    echo "entry like the following one..."
    echo ""
    echo "$(sudo -u "$NEPHIO_USER" id -nu) ALL=(ALL) NOPASSWD: ALL"
    exit 1
fi

if [[ $(id -u) -ne 0 ]]; then
    echo ""
    echo "This script must to be executed by the root user."
    echo ""
    exit 1
fi

if [[ $(sudo -u "$NEPHIO_USER" id -u) -eq 0 ]]; then
    echo ""
    echo "NEPHIO_USER cannot be root (user '$(sudo -u "$NEPHIO_USER" id -nu)')."
    echo ""
    exit 1
fi

if ! command -v git >/dev/null; then
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
    ubuntu | debian)
        # Removed the damaged list
        rm -rvf /var/lib/apt/lists/*
        apt-get update
        apt-get install -y git
        ;;
    rhel | centos | fedora | rocky)
        PKG_MANAGER=$(command -v dnf || command -v yum)
        $PKG_MANAGER install git -y
        ;;
    *)
        echo "OS not supported"
        exit
        ;;
    esac
fi

if [ ! -d "$REPO_DIR" ]; then
    runuser -u "$NEPHIO_USER" git clone "$REPO" "$REPO_DIR"
    if [[ $BRANCH != "main" ]]; then
        pushd "$REPO_DIR" >/dev/null
        TAG=$(runuser -u "$NEPHIO_USER" -- git tag --list $BRANCH)
        if [[ $TAG == $BRANCH ]]; then
            runuser -u "$NEPHIO_USER" -- git checkout --detach "$TAG"
        else
            runuser -u "$NEPHIO_USER" -- git checkout -b "$BRANCH" --track "origin/$BRANCH"
        fi
        popd >/dev/null
    fi
fi
find "$REPO_DIR" -name '*.sh' -exec chmod +x {} \;

cp "$REPO_DIR/e2e/provision/bash_config.sh" "$HOME/.bash_aliases"
chown "$NEPHIO_USER:$NEPHIO_USER" "$HOME/.bash_aliases"

# Sandbox Creation
int_start=$(date +%s)
cd "$REPO_DIR/e2e/provision"
export DEBUG DOCKERHUB_USERNAME DOCKERHUB_TOKEN FAIL_FAST
runuser -u "$NEPHIO_USER" ./install_sandbox.sh
printf "%s secs\n" "$(($(date +%s) - int_start))"

if [[ $RUN_E2E == "true" ]]; then
    runuser -u "$NEPHIO_USER" "$REPO_DIR/e2e/e2e.sh"
fi

echo "Done Nephio Execution"
