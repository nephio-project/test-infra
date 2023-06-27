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
## TEST-NAME: Deploy ueransim to edge clusters
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

k8s_apply "$kubeconfig" "$TESTDIR/007-edge-ueransim.yaml"

for cluster in "edge01" "edge02"; do
    k8s_wait_exists "$kubeconfig" 600 "default" "packagevariant" "edge-ueransim-${cluster}-ueransim"
done

for cluster in "edge01" "edge02"; do
    k8s_wait_ready "$kubeconfig" 600 "default" "packagevariant" "edge-ueransim-${cluster}-ueransim"
done

for cluster in "edge01" "edge02"; do
    cluster_kubeconfig=$(k8s_get_capi_kubeconfig "$kubeconfig" "default" "$cluster")
    k8s_wait_exists "$cluster_kubeconfig" 600 "ueransim" "deployment" "ueransim-gnb"
    k8s_wait_exists "$cluster_kubeconfig" 600 "ueransim" "deployment" "ueransim-ue"
    k8s_wait_ready_replicas "$cluster_kubeconfig" 600 "ueransim" "deployment" "ueransim-gnb"
    k8s_wait_ready_replicas "$cluster_kubeconfig" 600 "ueransim" "deployment" "ueransim-ue"
    ue_pod_name=${kubectl--kubeconfig $cluster_kubeconfig get pods -n ueransim  -l app=ueransim -l component=ue}
    k8s_exec $cluster_kubeconfig "ueransim" $ue_pod_name "ping -I uesimtun0 google.com"
done
