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

sudo apt-get clean
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install python3-venv python3-pip -y

python3 -m venv $HOME/.venv
source $HOME/.venv/bin/activate
pip install -r requirements.txt
ansible-galaxy collection install -r galaxy-requirements.yml

ssh-keygen -b 2048 -t rsa -f $HOME/.ssh/id_rsa -q -N ""
cat $HOME/.ssh/id_rsa.pub >>$HOME/.ssh/authorized_keys

apt-get -y install gcc-12
git clone -b v0.6.8 https://github.com/free5gc/gtp5g.git
cd gtp5g
make
make install
modprobe gtp5g
dmesg | tail -n 4

git clone --depth 1 https://github.com/nephio-project/one-summit-22-workshop.git $HOME/workshop
mkdir -p $HOME/workshop/nephio-ansible-install/inventory

cp $HOME/nephio.yaml $HOME/workshop/nephio-ansible-install/inventory/

pushd $HOME/workshop/nephio-ansible-install >/dev/null
for playbook in install-prereq create-gitea create-gitea-repos deploy-clusters configure-nephio; do
    [[ ${DEBUG:-false} != "true" ]] && ansible-playbook "playbooks/$playbook.yaml" || ansible-playbook -vvv "playbooks/$playbook.yaml"
done
popd >/dev/null
