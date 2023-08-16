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
## TEST-NAME: Deploy free5gc AMF and SMF to regional clusters
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

# apply both AMF and SMF so they both start processing
k8s_apply "$TESTDIR/006-regional-free5gc-amf.yaml"
k8s_apply "$TESTDIR/006-regional-free5gc-smf.yaml"

cluster_kubeconfig=$(k8s_get_capi_kubeconfig "regional")

# check the AMF
k8s_wait_ready "packagevariant" "regional-free5gc-amf-regional-free5gc-amf"
k8s_wait_ready_replicas "deployment" "amf-regional" "$cluster_kubeconfig" "free5gc-cp"

# check the SMF
k8s_wait_ready "packagevariant" "regional-free5gc-smf-regional-free5gc-smf"
k8s_wait_ready_replicas "deployment" "smf-regional" "$cluster_kubeconfig" "free5gc-cp"
