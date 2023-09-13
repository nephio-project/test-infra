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

# Install dependencies for it's ansible execution
source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
ubuntu | debian)
    sudo apt-get update
    sudo -E DEBIAN_FRONTEND=noninteractive apt-get remove -q -y python3-openssl
    sudo -E NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confnew" --allow-downgrades --allow-remove-essential --allow-change-held-packages -fuy install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" python3-pip
    ;;
rhel | centos | fedora | rocky)
    PKG_MANAGER=$(command -v dnf || command -v yum)
    sudo $PKG_MANAGER install python3-pip -y
    ;;
*)
    echo "OS not supported"
    exit
    ;;
esac

sudo pip install -r requirements.txt
ansible-galaxy role install -r galaxy-requirements.yml
ansible-galaxy collection install -r galaxy-requirements.yml

rm -f ~/.ssh/id_rsa*
echo -e "\n\n\n" | ssh-keygen -t rsa -N ""
cat "$HOME/.ssh/id_rsa.pub" >>"$HOME/.ssh/authorized_keys"

sudo mkdir -p /etc/ansible/
sudo tee /etc/ansible/ansible.cfg <<EOT
[ssh_connection]
# Enabling Pipelining
pipelining=True
# Enable SSH Multiplexing
ansible_ssh_common_args = -o ControlMaster=auto -o ControlPersist=30m -o ConnectionAttempts=100
retries=2

[defaults]
# Log Path
log_path = /var/log/deploy_sandbox.log
# Increase the forks
forks = 20
# Enable mitogen
strategy_plugins = $(dirname "$(sudo find / -name mitogen_linear.py | head -n 1)")
# Enable timing information
callbacks_enabled = timer, profile_tasks, profile_roles
# The playbooks is only run on the implicit localhost.
# Silence warning about empty hosts inventory.
localhost_warning = False
deprecation_warnings = False

# Disable host key checking
host_key_checking = False

# Enable facts caching mechanism
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp
EOT

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
        ansible-playbook -i 127.0.0.1, playbooks/cluster.yml
    else
        ansible-playbook -vvv -i 127.0.0.1, playbooks/cluster.yml
    fi
fi

echo "Done installing Nephio Sandbox Environment"
