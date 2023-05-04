#!/usr/bin/env bash
sudo apt-get clean
sudo apt-get update
yes | sudo  NEEDRESTART_SUSPEND=1  DEBIAN_FRONTEND=noninteractive apt-get install python3.10-venv python3-pip -y

python3 -m venv $HOME/.venv
source $HOME/.venv/bin/activate
pip install -r requirements.txt

ansible-galaxy collection install community.general
ansible-galaxy collection install kubernetes.docker
ansible-galaxy collection install kubernetes.core

ssh-keygen -b 2048 -t rsa -f /home/ubuntu/.ssh/id_rsa -q -N ""
cat /home/ubuntu/.ssh/id_rsa.pub >> /home/ubuntu/.ssh/authorized_keys

git clone https://github.com/nephio-project/one-summit-22-workshop.git

mkdir one-summit-22-workshop/nephio-ansible-install/inventory

cp /home/ubuntu/nephio.yaml one-summit-22-workshop/nephio-ansible-install/inventory/

cd one-summit-22-workshop/nephio-ansible-install

ansible-playbook playbooks/install-prereq.yaml
ansible-playbook playbooks/create-gitea.yaml
ansible-playbook playbooks/create-gitea-repos.yaml
ansible-playbook playbooks/deploy-clusters.yaml
ansible-playbook playbooks/configure-nephio.yaml
