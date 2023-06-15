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

    mkdir -p ~/.ssh/
    touch ~/.ssh/config
    if ! grep -q "StrictHostKeyChecking no" ~/.ssh/config; then
        echo "StrictHostKeyChecking no" >>~/.ssh/config
    fi
    chmod 600 ~/.ssh/config
    # Management cluster creation
    if [[ ${DEBUG:-false} != "true" ]]; then
        ansible-playbook -i ./nephio.yaml playbooks/cluster.yml
    else
        ansible-playbook -vvv -i ./nephio.yaml playbooks/cluster.yml
    fi
fi

echo "Done installing Nephio Sandbox Environment"
