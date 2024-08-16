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
## TEST-NAME: Deploy OAI RAN and Core Operators
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

k8s_apply "$TESTDIR/002-database.yaml"
k8s_apply "$TESTDIR/002-operators.yaml"

for pkgvar in common-core-database cp-operators up-operators ran-operator-edge ran-operator-regional; do
    k8s_wait_ready "packagevariant" "oai-$pkgvar"
done
kpt_wait_pkg "core" "database"
kpt_wait_pkg "core" "oai-cp-operators"
kpt_wait_pkg "edge" "oai-up-operators"
kpt_wait_pkg "regional" "oai-ran-operator"
kpt_wait_pkg "edge" "oai-ran-operator"

_core_kubeconfig="$(k8s_get_capi_kubeconfig "core")"
_edge_kubeconfig="$(k8s_get_capi_kubeconfig "edge")"
k8s_wait_ready_replicas "deployment" "mysql" "$_core_kubeconfig" "oai-core"
for nf in amf ausf nrf smf udm udr; do
    k8s_wait_ready_replicas "deployment" "oai-$nf-operator" "$_core_kubeconfig" "oai-cn-operators"
done
k8s_wait_ready_replicas "deployment" "oai-upf-operator" "$_edge_kubeconfig" "oai-cn-operators"
k8s_wait_ready_replicas "deployment" "oai-ran-operator" "$(k8s_get_capi_kubeconfig "regional")" "oai-ran-operators"
k8s_wait_ready_replicas "deployment" "oai-ran-operator" "$_edge_kubeconfig" "oai-ran-operators"
