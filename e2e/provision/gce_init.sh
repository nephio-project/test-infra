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

DEBUG=$(get_metadata nephio-setup-debug "false")

[[ "$DEBUG" != "true" ]] || set -o xtrace

DEPLOYMENT_TYPE=$(get_metadata nephio-setup-type "r1")
RUN_E2E=$(get_metadata nephio-run-e2e "false")
REPO=$(get_metadata nephio-test-infra-repo "https://github.com/nephio-project/test-infra.git")
BRANCH=$(get_metadata nephio-test-infra-branch "main")
NEPHIO_USER=${USER:-ubuntu}

echo "$DEBUG, $DEPLOYMENT_TYPE, $RUN_E2E, $REPO, $BRANCH"

# pre-configure the "docker" group and add the "ubuntu" user to it so that the docker
# and kpt fn apply commands will work without sudo
addgroup docker
usermod -a -G docker ubuntu

apt-get update
apt-get install -y git

<<<<<<< HEAD
cd /home/$NEPHIO_USER

=======

cd /home/$NEPHIO_USER

>>>>>>> b983ba6 (Additional e2e tests, and some conveniences (#70))
cat > .bash_aliases <<EOF
alias k=kubectl
EOF

chown $NEPHIO_USER:$NEPHIO_USER .bash_aliases

runuser -u $NEPHIO_USER git clone "$REPO" test-infra
if [[ "$BRANCH" != "main" ]]; then
  cd test-infra && runuser -u $NEPHIO_USER -- git checkout -b "$BRANCH" --track "origin/$BRANCH" && cd ..
fi

sed -e "s/vagrant/$NEPHIO_USER/" < /home/$NEPHIO_USER/test-infra/e2e/provision/nephio.yaml > /home/$NEPHIO_USER/nephio.yaml
cd ./test-infra/e2e/provision
export DEBUG DEPLOYMENT_TYPE
<<<<<<< HEAD

# Create the docker user now so that the NEPHIO_USER can be added to the docker group
# prior to installation of the management cluster installation.
if ! getent group docker > /dev/null; then
    addgroup docker
fi
=======
runuser -u $NEPHIO_USER ./gce_install_sandbox.sh
>>>>>>> b983ba6 (Additional e2e tests, and some conveniences (#70))

# Grant Docker permissions to current user
if ! getent group docker | grep -q "$NEPHIO_USER"; then
    sudo usermod -aG docker "$NEPHIO_USER"
fi
<<<<<<< HEAD

runuser -u $NEPHIO_USER ./gce_install_sandbox.sh
=======
>>>>>>> b983ba6 (Additional e2e tests, and some conveniences (#70))

if [[ "$RUN_E2E" == "true" ]]; then
  runuser -u $NEPHIO_USER ../e2e.sh
fi
