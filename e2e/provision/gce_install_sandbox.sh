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
[[ "${DEBUG:-false}" != "true" ]] || set -o xtrace

export HOME=${HOME:-/home/ubuntu/}

function deploy_kpt_pkg {
  local pkg=$1
  local name=$2

  local temp=$(mktemp -d -t kpt-XXXX)
  local localpkg="$temp/$name"
  /usr/local/bin/kpt pkg get --for-deployment "https://github.com/nephio-project/nephio-example-packages.git/$pkg" "$localpkg"
  # sudo because docker
  sudo /usr/local/bin/kpt fn render "$localpkg"
  /usr/local/bin/kpt live init "$localpkg"
  /usr/local/bin/kpt live apply "$localpkg"
}

sudo apt-get clean
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install python3-venv python3-pip -y

python3 -m venv "$HOME/.venv"
# shellcheck disable=SC1091
source "$HOME/.venv/bin/activate"
pip install -r requirements.txt
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
    deploy_kpt_pkg "repository@repository/v2" "mgmt"
    deploy_kpt_pkg "rootsync@rootsync/v2" "mgmt"

    deploy_kpt_pkg "repository@repository/v2" "mgmt-staging"
fi

echo "Done installing Nephio Sandbox Environment"
