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

# shellcheck source=e2e/defaults.env
source "$E2EDIR/defaults.env"

# shellcheck source=e2e/lib/k8s.sh
source "${LIBDIR}/k8s.sh"

# shellcheck source=e2e/lib/kpt.sh
source "${LIBDIR}/kpt.sh"

# shellcheck source=e2e/lib/porch.sh
source "${LIBDIR}/porch.sh"

# apply both AMF and SMF so they both start processing
k8s_apply "$TESTDIR/006-regional-free5gc-amf.yaml"
k8s_apply "$TESTDIR/006-regional-free5gc-smf.yaml"

cluster_kubeconfig=$(k8s_get_capi_kubeconfig "regional")

# check the NFs
for nf in amf smf; do
    k8s_wait_exists "packagevariant" "regional-free5gc-$nf-regional-free5gc-$nf"
    porch_wait_published_packagerev "free5gc-$nf" "regional"
    kpt_wait_pkg "regional" "free5gc-$nf"
    k8s_wait_ready_replicas "deployment" "$nf-regional" "$cluster_kubeconfig" "free5gc-cp"
done
