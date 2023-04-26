#!/usr/bin/env bash
sudo apt-get clean
sudo apt-get update
yes | sudo  NEEDRESTART_SUSPEND=1  DEBIAN_FRONTEND=noninteractive apt-get install python3.10-venv python3-pip -y

python3 -m venv venv
venv/bin/pip3 install ansible
venv/bin/pip3 install jmespath
venv/bin/ansible-galaxy collection install community.general
venv/bin/ansible-galaxy collection install kubernetes.core

cd /home/ubuntu/provision
../venv/bin/ansible-playbook -e ansible_connection=local -e ansible_user=ubuntu -e os_user=ubuntu -e os_group=ubuntu deploy_mk8s.yaml
