#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2023 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

DEBUG=$(curl -sf http://metadata.google.internal/computeMetadata/v1/instance/attributes/nephio-setup-debug -H "Metadata-Flavor: Google")
DEPLOYMENT_TYPE=$(curl -sf http://metadata.google.internal/computeMetadata/v1/instance/attributes/nephio-setup-type -H "Metadata-Flavor: Google")

set -o pipefail
set -o errexit
set -o nounset

[[ "${DEBUG:-false}" != "true" ]] || set -o xtrace

apt-get update

if ! command -v gcc >/dev/null; then
    if [[ $(uname -v) == *22.04.*-Ubuntu* ]]; then
      apt-get -y install gcc-12
    else
      apt-get -y install gcc
    fi
fi

apt-get install -y git
cd /home/ubuntu
#runuser -u ubuntu git clone https://github.com/nephio-project/test-infra.git
## These lines below are just to test without merging
runuser -u ubuntu git clone https://github.com/johnbelamaric/nephio-test-infra.git test-infra
cd test-infra
runuser -u ubuntu git checkout update-packages
cd ..
## end test lines

sed -e "s/vagrant/ubuntu/" < /home/ubuntu/test-infra/e2e/provision/nephio.yaml > /home/ubuntu/nephio.yaml
export DEBUG DEPLOYMENT_TYPE
cd ./test-infra/e2e/provision
runuser -u ubuntu ./gce_run.sh
