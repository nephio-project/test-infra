#!/bin/bash
#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2023 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

## TEST METADATA
## TEST-NAME: Wait for expected resources
##

set -o pipefail
set -o errexit
set -o nounset
[[ ${DEBUG:-false} != "true" ]] || set -o xtrace

export HOME=${HOME:-/home/ubuntu/}
export E2EDIR=${E2EDIR:-$HOME/test-infra/e2e}
export TESTDIR=${TESTDIR:-$E2EDIR/tests}
export LIBDIR=${LIBDIR:-$E2EDIR/lib}

source "${LIBDIR}/k8s.sh"

kubeconfig="$HOME/.kube/config"

k8s_wait_exists "$kubeconfig" 600 "default" "repository" "nephio-example-packages"

k8s_wait_exists "$kubeconfig" 600 "default" "repository" "mgmt"
k8s_wait_exists "$kubeconfig" 600 "default" "repository" "mgmt-staging"

k8s_wait_ready "$kubeconfig" 600 "default" "repository" "mgmt"
k8s_wait_ready "$kubeconfig" 600 "default" "repository" "mgmt-staging"
