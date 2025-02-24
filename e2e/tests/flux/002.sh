#!/bin/bash
#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2025 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

## TEST METADATA
## TEST-NAME: Deploy free5gc-cp to regional workload cluster
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

k8s_apply "$TESTDIR/002-free5gc-cp.yaml"

kubeconfig="$HOME/.kube/config"
k8s_wait_exists "packagevariant" "free5gc-control-plane"
porch_wait_published_packagerev "free5gc-cp" "regional" "$PACKAGE_REVISION"
kpt_wait_pkg "regional" "free5gc-cp"
k8s_wait_ready_replicas "statefulset" "mongodb" "$(k8s_get_capi_kubeconfig "regional")" "free5gc-cp"
