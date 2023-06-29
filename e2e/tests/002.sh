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
## TEST-NAME: Deploy edge clusters
##

set -o pipefail
set -o errexit
set -o nounset
[[ ${DEBUG:-false} != "true" ]] || set -o xtrace

export HOME=${HOME:-/home/ubuntu/}
export E2EDIR=${E2EDIR:-$HOME/test-infra/e2e}
export TESTDIR=${TESTDIR:-$E2EDIR/tests}
export LIBDIR=${LIBDIR:-$E2EDIR/lib}

source "${LIBDIR}/k8s.sh"

kubeconfig="$HOME/.kube/config"

k8s_apply "$kubeconfig" "$TESTDIR/002-edge-clusters.yaml"

# Wait for cluster resources creation
for cluster in edge01 edge02; do
    k8s_wait_exists "$kubeconfig" 600 "default" "workloadcluster" "$cluster"
    k8s_wait_exists "$kubeconfig" 600 "default" "cluster" "$cluster"
done

# Wait for cluster readiness
for cluster in $(kubectl get cluster -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --kubeconfig "$kubeconfig"); do
    k8s_wait_ready "$kubeconfig" 600 "default" "cluster" "$cluster"
    for machineset in $(kubectl get machineset -l cluster.x-k8s.io/cluster-name="$cluster" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --kubeconfig "$kubeconfig"); do
        k8s_wait_ready "$kubeconfig" 600 "default" "machineset" "$machineset"
    done
done

# Inter-connect worker nodes
$E2EDIR/provision/hacks/inter-connect_workers.sh

# Configure VLAN interfaces
$E2EDIR/provision/hacks/vlan-interfaces.sh
