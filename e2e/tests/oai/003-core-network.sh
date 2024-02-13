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
## TEST-NAME: Deploy OAI Core Network Functions
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

# shellcheck source=e2e/lib/_assertions.sh
source "${LIBDIR}/_assertions.sh"

function _wait_for_pfcp_session {
    local kubeconfig=$1

    info "waiting for PFCP session to be established"
    timeout=600
    until kubectl logs -l workload.nephio.org/oai=upf -n oai-core -c upf-edge --kubeconfig "$kubeconfig" --tail -1 | grep -q 'Received SX HEARTBEAT REQUEST'; do
        if [[ $timeout -lt 0 ]]; then
            kubectl logs -l workload.nephio.org/oai=upf -n oai-core -c upf-edge --kubeconfig "$kubeconfig" --tail 50
            error "Timed out waiting for PFCP session"
        fi
        timeout=$((timeout - 5))
        sleep 5
    done
    debug "timeout: $timeout"
}

_core_kubeconfig="$(k8s_get_capi_kubeconfig "core")"
_edge_kubeconfig="$(k8s_get_capi_kubeconfig "edge")"

k8s_apply "$TESTDIR/003-core-network.yaml"

for nf in nrf udm udr ausf amf smf; do
    k8s_wait_ready "packagevariant" "oai-$nf"
done
k8s_wait_ready "packagevariant" "oai-upf-edge"

for nf in nrf udm udr ausf amf; do
    kpt_wait_pkg "core" "oai-$nf"
    k8s_wait_exists "nfdeployment" "$nf-core" "$_core_kubeconfig" "oai-core"
    k8s_wait_ready_replicas "deployment" "$nf-core" "$_core_kubeconfig" "oai-core"
done
kpt_wait_pkg "edge" "oai-upf"
k8s_wait_exists "nfdeployment" "upf-edge" "$_edge_kubeconfig" "oai-core"
k8s_wait_ready_replicas "deployment" "upf-edge" "$_edge_kubeconfig" "oai-core"

kpt_wait_pkg "core" "oai-smf" "nephio" "1800"
k8s_wait_exists "nfdeployment" "smf-core" "$_core_kubeconfig" "oai-core"
k8s_wait_ready_replicas "deployment" "smf-core" "$_core_kubeconfig" "oai-core"

# Check if the PFCP session between UPF and SMF is established
_wait_for_pfcp_session "$_edge_kubeconfig"
