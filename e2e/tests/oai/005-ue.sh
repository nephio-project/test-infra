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
## TEST-NAME: Deploy OAI UE SIM
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

function _wait_for_ue {
    local kubeconfig=$1
    local log_msg=$2
    local msg=$3

    info "waiting for $msg to be finished"
    timeout=600
    temp_file=$(mktemp)
    kubectl logs -l app.kubernetes.io/name=oai-nr-ue --tail -1 -n oai-ue -c nr-ue --kubeconfig "$kubeconfig" >temp_file
    while
        grep -q "$log_msg" temp_file
        status=$?
        [ $status != 0 ]
    do
        if [[ $timeout -lt 0 ]]; then
            kubectl logs -l app.kubernetes.io/name=oai-nr-ue -n oai-ue -c nr-ue --kubeconfig "$kubeconfig" --tail 50
            error "Timed out waiting for $msg"
        fi
        timeout=$((timeout - 5))
        sleep 5
        kubectl logs -l app.kubernetes.io/name=oai-nr-ue --tail -1 -n oai-ue -c nr-ue --kubeconfig "$kubeconfig" >temp_file
    done
    debug "timeout: $timeout"
    rm "${temp_file}"
}

function _wait_for_ue_registration {
    _wait_for_ue "$1" "REGISTRATION ACCEPT" "UE Registration"
}

function _wait_for_ue_pdu_session {
    _wait_for_ue "$1" "Interface oaitun_ue1 successfully configured" "PDU session"
}

k8s_apply "$TESTDIR/005-ue.yaml"

k8s_wait_ready "packagevariant" "oai-ue"
kpt_wait_pkg "edge" "oai-ran-ue" "nephio" "1800"

_edge_kubeconfig="$(k8s_get_capi_kubeconfig "edge")"
k8s_wait_ready_replicas "deployment" "oai-nr-ue" "$_edge_kubeconfig" "oai-ue"

# Check if the Registration is finished
_wait_for_ue_registration "$_edge_kubeconfig"
# Check if the PDU Session is setup
_wait_for_ue_pdu_session "$_edge_kubeconfig"
