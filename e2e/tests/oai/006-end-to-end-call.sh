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
## TEST-NAME: Test OAI-UE connectivity
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

# Validate ue connectivity
_edge_kubeconfig="$(k8s_get_capi_kubeconfig "edge")"
upf_pod_name=$(kubectl get pods -n oai-core --kubeconfig "$_edge_kubeconfig" -l workload.nephio.org/oai=upf -o jsonpath='{.items[*].metadata.name}')
upf_tun0_ip_addr=$(kubectl exec -it $upf_pod_name -n oai-core -c upf-edge --kubeconfig "$_edge_kubeconfig" -- ip -f inet addr show tun0 | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')
ue_pod_name=$(kubectl get pods -n oai-ue --kubeconfig "$_edge_kubeconfig" -l app.kubernetes.io/name=oai-nr-ue -o jsonpath='{.items[*].metadata.name}')

k8s_exec "$_edge_kubeconfig" "oai-ue" "$ue_pod_name" "ping -I oaitun_ue1 -c 3 $upf_tun0_ip_addr"
