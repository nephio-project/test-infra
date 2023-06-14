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

DEBUG=${DEBUG:-false}

[[ $DEBUG != "true" ]] || set -o xtrace

VM=${1:-nephio-r1-e2e}
RUNE2E=${2:-false}
REPO=${3:-nephio-project/test-infra}
BRANCH=${4:-main}

STARTUP_SCRIPT_URL="https://raw.githubusercontent.com/$REPO/$BRANCH/e2e/provision/init.sh"
FULLREPO="https://github.com/$REPO.git"

gcloud compute instances delete -q "$VM" || echo
gcloud compute instances create \
    --machine-type e2-standard-8 \
    --boot-disk-size 200GB \
    --image-family=ubuntu-2004-lts \
    --image-project=ubuntu-os-cloud \
    "--metadata=startup-script-url=$STARTUP_SCRIPT_URL,nephio-run-e2e=$RUNE2E,nephio-test-infra-repo=$FULLREPO,nephio-test-infra-branch=$BRANCH,nephio-setup-debug=$DEBUG" \
    "$VM"

echo "Waiting for instance to become available..."

sleep 30

ORGNAME=$(gcloud organizations describe $(gcloud projects get-ancestors $(gcloud config get project) | grep organization | cut -f 1 -d ' ') | grep displayName | cut -f 2 -d : | tr -d ' ')

echo "Organization is '$ORGNAME'"

OPTS=""
if [[ $ORGNAME == "google.com" ]]; then
    OPTS='-o ProxyCommand="corp-ssh-helper %h %p"'
fi

function print_ssh_message {
    cat <<EOF

To reconnect and see the startup script output:

gcloud compute ssh ubuntu@${VM} -- $OPTS sudo journalctl -u google-startup-scripts.service --follow

To ssh to the VM:

gcloud compute ssh ubuntu@${VM} -- $OPTS

To ssh with a tunnel to Gitea and the UI, including kubectl port-forward:

gcloud compute ssh ubuntu@${VM} -- $OPTS -L 7007:localhost:7007 -L 3000:172.18.0.200:3000 kubectl port-forward --namespace=nephio-webui svc/nephio-webui 7007

EOF
}

trap "print_ssh_message" INT
echo gcloud compute ssh ubuntu@${VM} -- $OPTS sudo journalctl -u google-startup-scripts.service --follow | /bin/bash
