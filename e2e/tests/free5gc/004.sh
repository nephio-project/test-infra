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
## TEST-NAME: Deploy free5gc operator to all workload clusters
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

k8s_apply "$TESTDIR/004-free5gc-operator.yaml"

kubeconfig="$HOME/.kube/config"
for cluster in $(kubectl get cl -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --kubeconfig "$kubeconfig"); do
    k8s_wait_exists "packagevariant" "free5gc-operator-$cluster-free5gc-operator"
    porch_wait_published_packagerev "free5gc-operator" "$cluster"
    kpt_wait_pkg "$cluster" "free5gc-operator"
    k8s_wait_ready_replicas "deployment" "free5gc-operator" "$(k8s_get_capi_kubeconfig "$cluster")" "free5gc"
done
