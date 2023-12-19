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
    until kubectl logs "$(kubectl get pods -n oai-ue --kubeconfig "$kubeconfig" -l app.kubernetes.io/name=oai-nr-ue -o jsonpath='{.items[*].metadata.name}')" -n oai-ue -c nr-ue --kubeconfig "$kubeconfig" | grep -q "$log_msg"; do
        if [[ $timeout -lt 0 ]]; then
            kubectl logs -l app.kubernetes.io/name=oai-nr-ue -n oai-ue -c nr-ue --kubeconfig "$kubeconfig" --tail 50
            error "Timed out waiting for $msg"
        fi
        timeout=$((timeout - 5))
        sleep 5
    done
    debug "timeout: $timeout"
}

function _wait_for_ue_registration {
    _wait_for_ue "$1" "REGISTRATION ACCEPT" "UE Registration"
}

function _wait_for_ue_pdu_session {
    _wait_for_ue "$1" "Interface oaitun_ue1 successfully configured" "PDU session"
}

cat <<EOF | kubectl apply -f -
apiVersion: config.porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: oai-ue
spec:
  upstream:
    repo: catalog
    package: workloads/oai/pkg-example-ue-bp
    revision: main
  downstream:
    repo: edge
    package: oai-ran-ue
  annotations:
    approval.nephio.org/policy: initial
  injectors:
  - name: edge
EOF

kpt_wait_pkg "edge" "oai-ran-ue"
k8s_wait_ready "packagevariant" "oai-ue"
_edge_kubeconfig="$(k8s_get_capi_kubeconfig "edge")"
k8s_wait_ready_replicas "deployment" "oai-nr-ue" "$_edge_kubeconfig" "oai-ue"

# Check if the Registration is finished
_wait_for_ue_registration "$_edge_kubeconfig"
# Check if the PDU Session is setup
_wait_for_ue_pdu_session "$_edge_kubeconfig"
