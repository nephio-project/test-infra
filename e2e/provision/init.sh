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

function get_metadata {
    local md=$1
    local df=$2

    echo $(curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$md" -H "Metadata-Flavor: Google" || echo "$df")
}

DEBUG=${NEPHIO_DEBUG:-$(get_metadata nephio-setup-debug "false")}

[[ $DEBUG != "true" ]] || set -o xtrace

DEPLOYMENT_TYPE=${NEPHIO_DEPLOYMENT_TYPE:-$(get_metadata nephio-setup-type "r1")}
RUN_E2E=${NEPHIO_RUN_E2E:-$(get_metadata nephio-run-e2e "false")}
REPO=${NEPHIO_REPO:-$(get_metadata nephio-test-infra-repo "https://github.com/nephio-project/test-infra.git")}
BRANCH=${NEPHIO_BRANCH:-$(get_metadata nephio-test-infra-branch "main")}
export USER=${NEPHIO_USER:-ubuntu}

echo "$DEBUG, $DEPLOYMENT_TYPE, $RUN_E2E, $REPO, $BRANCH, $USER"

if ! command -v git>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y git
fi

cd /home/$USER

runuser -u $USER git clone "$REPO" test-infra
if [[ "$BRANCH" != "main" ]]; then
    cd test-infra && runuser -u $USER -- git checkout -b "$BRANCH" --track "origin/$BRANCH" && cd ..
fi

cp /home/$USER/test-infra/e2e/provision/bash_config.sh /home/$USER/.bash_aliases
chown $USER:$USER /home/$USER/.bash_aliases

sed -e "s/vagrant/$USER/" < /home/$USER/test-infra/e2e/provision/nephio.yaml > /home/$USER/nephio.yaml
cd ./test-infra/e2e/provision
export DEBUG DEPLOYMENT_TYPE
runuser -u $USER ./install_sandbox.sh

# Grant Docker permissions to current user
if ! getent group docker | grep -q "$USER"; then
    sudo usermod -aG docker "$USER"
fi

if [[ "$RUN_E2E" == "true" ]]; then
    runuser -u $USER ../e2e.sh
fi
