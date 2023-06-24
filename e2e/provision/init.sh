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

    curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$md" -H "Metadata-Flavor: Google" || echo "$df"
}

export DEBUG=${NEPHIO_DEBUG:-$(get_metadata nephio-setup-debug "false")}

[[ $DEBUG != "true" ]] || set -o xtrace

DEPLOYMENT_TYPE=${NEPHIO_DEPLOYMENT_TYPE:-$(get_metadata nephio-setup-type "r1")}
RUN_E2E=${NEPHIO_RUN_E2E:-$(get_metadata nephio-run-e2e "false")}
REPO=${NEPHIO_REPO:-$(get_metadata nephio-test-infra-repo "https://github.com/nephio-project/test-infra.git")}
BRANCH=${NEPHIO_BRANCH:-$(get_metadata nephio-test-infra-branch "main")}
NEPHIO_USER=${NEPHIO_USER:-$(get_metadata nephio-user "ubuntu")}
HOME=${NEPHIO_HOME:-/home/$NEPHIO_USER}
REPO_DIR=${NEPHIO_REPO_DIR:-$HOME/test-infra}

echo "$DEBUG, $DEPLOYMENT_TYPE, $RUN_E2E, $REPO, $BRANCH, $NEPHIO_USER, $HOME, $REPO_DIR"

if ! command -v git >/dev/null; then
    apt-get update
    apt-get install -y git
fi

if [ ! -d "$REPO_DIR" ]; then
    runuser -u "$NEPHIO_USER" git clone "$REPO" "$REPO_DIR"
    if [[ $BRANCH != "main" ]]; then
        pushd "$REPO_DIR" >/dev/null
        runuser -u "$NEPHIO_USER" -- git checkout -b "$BRANCH" --track "origin/$BRANCH"
        popd >/dev/null
    fi
fi
find "$REPO_DIR" -name '*.sh' -exec chmod +x {} \;

cp "$REPO_DIR/e2e/provision/bash_config.sh" "$HOME/.bash_aliases"
chown "$NEPHIO_USER:$NEPHIO_USER" "$HOME/.bash_aliases"

sed -e "s/vagrant/$NEPHIO_USER/" <"$REPO_DIR/e2e/provision/nephio.yaml" >"$HOME/nephio.yaml"

cd "$REPO_DIR/e2e/provision"
export DEBUG DEPLOYMENT_TYPE
runuser -u "$NEPHIO_USER" ./install_sandbox.sh

# Grant Docker permissions to current user
if ! getent group docker | grep -q "$NEPHIO_USER"; then
    sudo usermod -aG docker "$NEPHIO_USER"
fi

if [[ $RUN_E2E == "true" ]]; then
    runuser -u "$NEPHIO_USER" "$REPO_DIR/e2e/e2e.sh"
fi
