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

[[ "$DEBUG" != "true" ]] || set -o xtrace

VM=${1:-nephio-r1-e2e}
RUNE2E=${2:-false}
REPO=${3:-nephio-project/test-infra}
BRANCH=${4:-main}

STARTUP_SCRIPT_URL="https://raw.githubusercontent.com/$REPO/$BRANCH/e2e/provision/gce_init.sh"
FULLREPO="https://github.com/$REPO.git"

gcloud compute instances delete -q "$VM" || echo
gcloud compute instances create   \
  --machine-type e2-standard-8    \
  --boot-disk-size 200GB          \
  --image-family=ubuntu-2004-lts  \
  --image-project=ubuntu-os-cloud \
  "--metadata=startup-script-url=$STARTUP_SCRIPT_URL,nephio-run-e2e=$RUNE2E,nephio-test-infra-repo=$FULLREPO,nephio-test-infra-branch=$BRANCH,nephio-setup-debug=$DEBUG" \
  "$VM"

echo "Waiting for instance to become available..."

sleep 30

ORGNAME=$(gcloud organizations describe $(gcloud projects get-ancestors $(gcloud config get project) | grep organization | cut -f 1 -d ' ') | grep displayName | cut -f 2 -d : | tr -d ' ')

echo "Organization is '$ORGNAME'"

OPTS=""
if [[ "$ORGNAME" == "google.com" ]]; then
  OPTS="-o ProxyCommand='corp-ssh-helper %h %p'"
fi

echo gcloud compute ssh $VM -- $OPTS sudo journalctl -u google-startup-scripts.service --follow | /bin/bash
