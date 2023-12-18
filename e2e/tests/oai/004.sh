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
## TEST-NAME: Deploy OAI E1 Split RAN Network Functions
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

function _wait_for_n2_link {
    local kubeconfig=$1

    info "waiting for N2 link to be established"
    timeout=600
    until kubectl logs "$(kubectl get pods -n oai-ran-cucp --kubeconfig "$kubeconfig" -l app.kubernetes.io/name=oai-gnb-cu-cp -o jsonpath='{.items[*].metadata.name}')" -n oai-ran-cucp -c gnbcucp --kubeconfig "$kubeconfig" | grep -q 'Received NGAP_REGISTER_GNB_CNF: associated AMF'; do
        if [[ $timeout -lt 0 ]]; then
            kubectl logs -l app.kubernetes.io/name=oai-gnb-cu-cp -n oai-ran-cucp -c gnbcucp --kubeconfig "$kubeconfig" --tail 50
            error "Timed out waiting for N2 link to be established"
        fi
        timeout=$((timeout - 5))
        sleep 5
    done
    debug "timeout: $timeout"
}

function _wait_for_e1_link {
    local kubeconfig=$1
    # Connection between CU-CP and CU-UP
    info "waiting for E1 link to be established"
    timeout=600
    until kubectl logs "$(kubectl get pods -n oai-ran-cucp --kubeconfig "$kubeconfig" -l app.kubernetes.io/name=oai-gnb-cu-cp -o jsonpath='{.items[*].metadata.name}')" -n oai-ran-cucp -c gnbcucp --kubeconfig "$kubeconfig" | grep -q 'e1ap_send_SETUP_RESPONSE'; do
        if [[ $timeout -lt 0 ]]; then
            kubectl logs -l app.kubernetes.io/name=oai-gnb-cu-cp -n oai-ran-cucp -c gnbcucp --kubeconfig "$kubeconfig" --tail 50
            error "Timed out waiting for E1 link to be established"
        fi
        timeout=$((timeout - 5))
        sleep 5
    done
    debug "timeout: $timeout"
}

function _wait_for_f1_link {
    local kubeconfig=$1
    # Connection between DU and CU-CP
    info "waiting for F1 link to be established"
    timeout=600
    until kubectl logs "$(kubectl get pods -n oai-ran-cucp --kubeconfig "$kubeconfig" -l app.kubernetes.io/name=oai-gnb-cu-cp -o jsonpath='{.items[*].metadata.name}')" -n oai-ran-cucp -c gnbcucp --kubeconfig "$kubeconfig" | grep -q 'Cell Configuration ok'; do
        if [[ $timeout -lt 0 ]]; then
            kubectl logs -l app.kubernetes.io/name=oai-gnb-cu-cp -n oai-ran-cucp -c gnbcucp --kubeconfig "$kubeconfig" --tail 50
            error "Timed out waiting for F1 link to be established"
        fi
        timeout=$((timeout - 5))
        sleep 5
    done
    debug "timeout: $timeout"
}

cat <<EOF | kubectl apply -f -
apiVersion: config.porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: oai-cucp
spec:
  upstream:
    repo: oai-ran-packages
    package: pkg-example-cucp-bp
    revision: v1
  downstream:
    repo: regional
    package: oai-ran-cucp
  annotations:
    approval.nephio.org/policy: initial
  injectors:
  - name: regional
EOF

kpt_wait_pkg "regional" "oai-cucp"

for nf in du cuup; do
    cat <<EOF | kubectl apply -f -
apiVersion: config.porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: oai-$nf
spec:
  upstream:
    repo: oai-ran-packages 
    package: pkg-example-$nf-bp
    revision: v1
  downstream:
    repo: edge
    package: oai-ran-$nf
  annotations:
    approval.nephio.org/policy: initial
  injectors:
  - name: edge
EOF
done


for nf in du cuup; do
    k8s_wait_ready "packagevariant" "oai-$nf"
done

for nf in du cuup; do
    kpt_wait_pkg "edge" "oai-ran-$nf" "nephio" "900"
done

_regional_kubeconfig="$(k8s_get_capi_kubeconfig "regional")"
_edge_kubeconfig="$(k8s_get_capi_kubeconfig "edge")"

k8s_wait_ready_replicas "deployment" "oai-gnb-cu-cp" "$_regional_kubeconfig" "oai-ran-cucp"
k8s_wait_ready_replicas "deployment" "oai-gnb-cu-up" "$_edge_kubeconfig" "oai-ran-cuup"
k8s_wait_ready_replicas "deployment" "oai-gnb-du" "$_edge_kubeconfig" "oai-ran-du"

# Check if the NGAPSetup Request Response is okay between AMF and CU-CP
_wait_for_n2_link "$_regional_kubeconfig"
# Check if the E1Setup Request Response is okay between AMF and CU-CP
_wait_for_e1_link "$_regional_kubeconfig"
# Check if the F1Setup Request Response is okay between AMF and CU-CP
_wait_for_f1_link "$_regional_kubeconfig"
