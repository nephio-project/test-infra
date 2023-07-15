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
## TEST-NAME: Deploy regional workload cluster
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

cd /tmp/kpt-pkg/nephio-stock-repos
kpt fn eval --image gcr.io/kpt-fn/search-replace:unstable -- by-path='spec.git.repo' by-file-path='repo-nephio-example-packages.yaml' put-value='https://github.com/johnbelamaric/nephio-example-packages.git'
kpt live apply

cd /tmp/kpt-pkg/nephio-controllers
kpt fn eval --image gcr.io/kpt-fn/set-image:unstable -- name=docker.io/nephio/nephio-operator newTag=jbelamaric
kpt live apply
