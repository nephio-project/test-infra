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

for nf in nrf udm udr ausf amf smf; do
    cat <<EOF | kubectl apply -f -
apiVersion: config.porch.kpt.dev/v1alpha2
kind: PackageVariantSet
metadata:
  name: oai-$nf
spec:
  upstream:
    repo: oai-packages
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
    kpt_wait_pkg "core" "oai-$nf" "nephio" "900"
done
kpt_wait_pkg "edge" "oai-upf"

_core_kubeconfig="$(k8s_get_capi_kubeconfig "core")"
_edge_kubeconfig="$(k8s_get_capi_kubeconfig "edge")"
for nf in nrf udm udr ausf amf smf; do
    k8s_wait_ready_replicas "deployment" "$nf-core" "$_core_kubeconfig" "oai-core"
done
k8s_wait_ready_replicas "deployment" "upf-edge" "$_edge_kubeconfig" "oai-core"

# TODO: Verify PFCP session
#upf_podname=$(kubectl get pods -n oai-core --kubeconfig "$_edge_kubeconfig" -l workload.nephio.org/oai=upf -o jsonpath='{.items[*].metadata.name}')
#kubectl logs "$upf_podname" -n oai-core -c upf-edge --kubeconfig "$_edge_kubeconfig" | grep 'Received SX HEARTBEAT REQUEST' | wc -l
