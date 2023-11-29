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
## TEST-NAME: Deploy and interconnect OAI clusters
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

# shellcheck source=e2e/lib/capi.sh
source "${LIBDIR}/capi.sh"

k8s_apply "$TESTDIR/001-infra.yaml"

# Wait for cluster resources creation
for cluster in core regional edge; do
    k8s_wait_exists "workloadcluster" "$cluster"
    k8s_wait_exists "packagevariant" "oai-$cluster-clusters-mgmt-$cluster"
    k8s_wait_exists "cl" "$cluster"
done

# Wait for cluster readiness
kubeconfig="$HOME/.kube/config"
for cluster in $(kubectl get cl -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --kubeconfig "$kubeconfig"); do
    capi_cluster_ready "$cluster"
done

# Inter-connect worker nodes
"$E2EDIR/provision/hacks/inter-connect_workers.sh"

# Configure VLAN interfaces
"$E2EDIR/provision/hacks/vlan-interfaces.sh"

# Create network package variant
k8s_apply "$TESTDIR/001-network.yaml"

# Provide a secret for external backend connection
k8s_apply "$TESTDIR/001-secret.yaml"

k8s_wait_ready "packagevariant" "network"
kpt_wait_pkg "mgmt" "network"

# Generate a RawTopology to interconnect clusters
"$E2EDIR/provision/hacks/network-topo.sh"
