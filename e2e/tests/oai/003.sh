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
    until kubectl logs "$(kubectl get pods -n oai-core --kubeconfig "$kubeconfig" -l workload.nephio.org/oai=upf -o jsonpath='{.items[*].metadata.name}')" -n oai-core -c upf-edge --kubeconfig "$kubeconfig" | grep -q 'Received SX HEARTBEAT REQUEST'; do
        if [[ $timeout -lt 0 ]]; then
            kubectl logs -l workload.nephio.org/oai=upf -n oai-core -c upf-edge --kubeconfig "$kubeconfig" --tail 50
            error "Timed out waiting for PFCP session"
        fi
        timeout=$((timeout - 5))
        sleep 5
    done
    debug "timeout: $timeout"
}

for nf in nrf udm udr ausf amf smf; do
    cat <<EOF | kubectl apply -f -
apiVersion: config.porch.kpt.dev/v1alpha2
kind: PackageVariantSet
metadata:
  name: oai-$nf
spec:
  upstream:
    repo: oai-core-packages
    package: oai-$nf
    revision: r2
  targets:
  - objectSelector:
      apiVersion: infra.nephio.org/v1alpha1
      kind: WorkloadCluster
      matchLabels:
        nephio.org/site-type: core
    template:
      downstream:
        package: oai-$nf
      annotations:
        approval.nephio.org/policy: initial
      injectors:
      - nameExpr: target.name
EOF
done
k8s_apply "$TESTDIR/003-upf.yaml"

for nf in nrf udm udr ausf amf smf; do
    k8s_wait_ready "packagevariant" "oai-$nf-core-oai-$nf"
done
for nf in nrf udm udr ausf amf smf; do
    kpt_wait_pkg "core" "oai-$nf" "nephio" "1800"
done
kpt_wait_pkg "edge" "oai-upf"

_core_kubeconfig="$(k8s_get_capi_kubeconfig "core")"
_edge_kubeconfig="$(k8s_get_capi_kubeconfig "edge")"
for nf in nrf udm udr ausf amf smf; do
    k8s_wait_ready_replicas "deployment" "$nf-core" "$_core_kubeconfig" "oai-core"
done
k8s_wait_ready_replicas "deployment" "upf-edge" "$_edge_kubeconfig" "oai-core"

# Check if the PFCP session between UPF and SMF is established
_wait_for_pfcp_session "$_edge_kubeconfig"
