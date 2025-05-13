#!/bin/bash
#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2024 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

## TEST METADATA
## TEST-NAME: Deploy OAI CU-CP Network Function
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

function _wait_for_ran {
    kubeconfig=$1
    wait_msg=$2
    link_name=$3

    info "waiting for $link_name link to be established"
    timeout=600

    temp_file=$(mktemp)
    kubectl logs -l app.kubernetes.io/name=oai-gnb-cu-cp --tail -1 -n oai-ran-cucp -c gnbcucp --kubeconfig "$kubeconfig" >temp_file
    while
        grep "$wait_msg" temp_file
        status=$?
        [[ $status != 0 ]]
    do
        if [[ $timeout -lt 0 ]]; then
            kubectl logs -l app.kubernetes.io/name=oai-gnb-cu-cp -n oai-ran-cucp -c gnbcucp --kubeconfig "$kubeconfig" --tail 50
            error "Timed out waiting for $link_name link to be established"
        fi
        timeout=$((timeout - 5))
        sleep 5
        kubectl logs -l app.kubernetes.io/name=oai-gnb-cu-cp --tail -1 -n oai-ran-cucp -c gnbcucp --kubeconfig "$kubeconfig" >temp_file
    done
    debug "timeout: $timeout"
    rm "${temp_file}"
}

_regional_kubeconfig="$(k8s_get_capi_kubeconfig "regional")"

k8s_apply "$TESTDIR/004a-ran-network.yaml"

k8s_wait_ready "packagevariant" "oai-cucp"

porch_wait_published_packagerev "oai-ran-cucp" "regional" "packagevariant-1"
kpt_wait_pkg "regional" "oai-ran-cucp" "nephio" "1800"
k8s_wait_exists "nfdeployment" "cucp-regional" "$_regional_kubeconfig" "oai-ran-cucp"
k8s_wait_ready_replicas "deployment" "oai-gnb-cu-cp" "$_regional_kubeconfig" "oai-ran-cucp"

# Check if the NGAPSetup Request Response is okay between AMF and CU-CP
_wait_for_ran "$_regional_kubeconfig" "Received NGAP_REGISTER_GNB_CNF: associated AMF" "N2"
