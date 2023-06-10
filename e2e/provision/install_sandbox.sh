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
[[ ${DEBUG:-false} != "true" ]] || set -o xtrace

export HOME=${HOME:-/home/ubuntu/}

# get_status() - Print the current status of the management cluster
function get_status {
    set +o xtrace
    printf "CPU usage: "
    grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage " %"}'
    printf "Memory free(Kb):"
    awk -v low="$(grep low /proc/zoneinfo | awk '{k+=$2}END{print k}')" '{a[$1]=$2}  END{ print a["MemFree:"]+a["Active(file):"]+a["Inactive(file):"]+a["SReclaimable:"]-(12*low);}' /proc/meminfo
    echo "Kubernetes Events:"
    sudo kubectl get events
    echo "Kubernetes Resources:"
    sudo kubectl get all -A -o wide
}

function deploy_kpt_pkg {
    local pkg=$1
    local name=$2

    local temp=$(mktemp -d -t kpt-XXXX)
    local localpkg="$temp/$name"
    kpt pkg get --for-deployment "https://github.com/nephio-project/nephio-example-packages.git/$pkg" "$localpkg"
    # sudo because docker
    sudo kpt fn render "$localpkg"
    kpt live init "$localpkg"
    kubectl --kubeconfig "$HOME/.kube/config" api-resources
    kpt pkg tree "$localpkg"
    let retries=5
    while [[ $retries -gt 0 ]]; do
        if kpt live --kubeconfig "$HOME/.kube/config" apply "$localpkg" --reconcile-timeout 10m; then
            retries=0
        else
            retries=$((retries - 1))
            sleep 5
        fi
    done
}

# Install dependencies for it's ansible execution
sudo apt-get update
sudo -E DEBIAN_FRONTEND=noninteractive apt-get remove -q -y python3-openssl
sudo -E NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confnew" --allow-downgrades --allow-remove-essential --allow-change-held-packages -fuy install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" python3-pip
sudo pip install -r requirements.txt
ansible-galaxy role install -r galaxy-requirements.yml
ansible-galaxy collection install -r galaxy-requirements.yml

rm -f ~/.ssh/id_rsa*
echo -e "\n\n\n" | ssh-keygen -t rsa -N ""
cat "$HOME/.ssh/id_rsa.pub" >>"$HOME/.ssh/authorized_keys"

KVER=$(uname -r)

if ! lsmod | grep -q gtp5g; then
    [[ -d "$HOME/gtp5g" ]] || git clone --depth 1 -b v0.6.8 https://github.com/free5gc/gtp5g.git "$HOME/gtp5g"

    pushd "$HOME/gtp5g" >/dev/null
    GCC=gcc
    if [[ $(uname -v) == *22.04.*-Ubuntu* ]]; then
        GCC=gcc-12
    fi
    if ! command -v $GCC >/dev/null; then
        sudo apt-get -y install $GCC
    fi
    if [[ ! -d "/lib/modules/$KVER/build" ]]; then
        sudo apt-get -y install "linux-headers-$KVER"
    fi
    make
    sudo make install
    sudo modprobe gtp5g
    sudo dmesg | tail -n 4
    popd >/dev/null
fi

if [ "${DEPLOYMENT_TYPE:-r1}" == "one-summit" ]; then
    [[ -d "$HOME/workshop" ]] || git clone --depth 1 https://github.com/nephio-project/one-summit-22-workshop.git "$HOME/workshop"
    mkdir -p "$HOME/workshop/nephio-ansible-install/inventory"
    cp "$HOME/nephio.yaml" "$HOME/workshop/nephio-ansible-install/inventory/"
    pushd "$HOME/workshop/nephio-ansible-install" >/dev/null
    for playbook in install-prereq create-gitea create-gitea-repos deploy-clusters configure-nephio; do
        if [[ ${DEBUG:-false} != "true" ]]; then
            ansible-playbook "playbooks/$playbook.yaml"
        else
            ansible-playbook -vvv "playbooks/$playbook.yaml"
        fi
    done
    popd >/dev/null
else
    trap get_status ERR
    # Management cluster creation
    if [[ ${DEBUG:-false} != "true" ]]; then
        ansible-playbook -i ~/nephio.yaml playbooks/cluster.yml
    else
        ansible-playbook -vvv -i ~/nephio.yaml playbooks/cluster.yml
    fi

    # Put this in the ubuntu dir and make it accessible to world
    mkdir "$HOME/.kube" && chmod 755 "$HOME/.kube"
    sudo cp /root/.kube/config "$HOME/.kube"
    sudo chown $USER:$USER "$HOME/.kube/config"
    chmod 644 "$HOME/.kube/config"

    # I don't know how to make ansible do what I want, this is what I want
    deploy_kpt_pkg "repository@repository/v3" "mgmt"
    deploy_kpt_pkg "rootsync@rootsync/v3" "mgmt"

    deploy_kpt_pkg "repository@repository/v3" "mgmt-staging"
fi

echo "Done installing Nephio Sandbox Environment"
