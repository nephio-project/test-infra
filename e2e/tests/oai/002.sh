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

#adding directory path to register repository to have upstream packages in repository subdirectory when used with packagevariantset
#TODO: to change the private catalog repository to nephio catalog repository after PR approval
kpt alpha repo register --namespace default https://github.com/josephthaliath/catalog.git --directory=workloads/oai --name=oai-ran-packages

k8s_apply "$TESTDIR/002-oai-operators.yaml"

for pkgvar in common-core-database cp-operators up-operators ran-operator-edge-oai-ran-operator ran-operator-regional-oai-ran-operator; do
    k8s_wait_ready "packagevariant" "oai-$pkgvar"
done
kpt_wait_pkg "core" "database"
kpt_wait_pkg "core" "oai-cp-operators"
kpt_wait_pkg "edge" "oai-up-operators"
kpt_wait_pkg "regional" "oai-ran-operator"
kpt_wait_pkg "edge" "oai-ran-operator"

_core_kubeconfig="$(k8s_get_capi_kubeconfig "core")"
k8s_wait_ready_replicas "deployment" "mysql" "$_core_kubeconfig" "oai-core"
for controller in amf ausf nrf smf udm udr; do
    k8s_wait_ready_replicas "deployment" "oai-$controller-controller" "$_core_kubeconfig" "oai-operators"
done
k8s_wait_ready_replicas "deployment" "oai-upf-controller" "$(k8s_get_capi_kubeconfig "edge")" "oai-operators"
k8s_wait_ready_replicas "deployment" "oai-ran-operator" "$(k8s_get_capi_kubeconfig "regional")" "oai-ran-operators"
k8s_wait_ready_replicas "deployment" "oai-ran-operator" "$(k8s_get_capi_kubeconfig "edge")" "oai-ran-operators"
