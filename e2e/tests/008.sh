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
## TEST-NAME: Vertically Scale free5gc UPF in Edge Clusters
## Usage : 008.sh <Capacity> , Capacity > 5G

set -o pipefail
set -o errexit
set -o nounset
[[ ${DEBUG:-false} != "true" ]] || set -o xtrace

# Set the new value for maxUplinkThroughput as a parameter
new_capacity_value=${1:-20G}

export HOME=${HOME:-/home/ubuntu/}
export E2EDIR=${E2EDIR:-$HOME/test-infra/e2e}
export TESTDIR=${TESTDIR:-$E2EDIR/tests}
export LIBDIR=${LIBDIR:-$E2EDIR/lib}

source "${LIBDIR}/k8s.sh"

kubeconfig="$HOME/.kube/config"

for cluster in "edge01"; do

    #Get the cluster kubeconfig
    echo "Getting kubeconfig for $cluster"
    cluster_kubeconfig=$(k8s_get_capi_kubeconfig "$kubeconfig" "default" "$cluster")

    #Before scaling test get the running UPF POD ID
    echo "Getting pod for UPF in cluster $cluster"
    upf_pod_id=$(kubectl --kubeconfig $cluster_kubeconfig get pods -l name=upf-${cluster} -n free5gc-upf | grep upf | head -1 | cut -d ' ' -f 1)

    if [ -z "$upf_pod_id" ]; then
        echo "UPF Pod Not Found"
        exit 1
    fi

    echo "Getting CPU for $upf_pod_id"
    #If the pod exists, Get the current CPU and Memory limit
    current_cpu=$(k8s_get_first_container_requests $cluster_kubeconfig free5gc-upf $upf_pod_id "cpu")

    echo "Getting memory for $upf_pod_id"
    current_memory=$(k8s_get_first_container_requests $cluster_kubeconfig free5gc-upf $upf_pod_id "memory")

    echo "Current CPU $current_cpu"
    echo "Current Memory $current_memory"

    #Scale the POD
    upf_deployment_pkg=$(kubectl --kubeconfig $kubeconfig get packagevariant edge-free5gc-upf-${cluster}-free5gc-upf -o jsonpath='{.status.downstreamTargets[0].name}')
    echo "Copying $upf_deployment_pkg"
    ws="${cluster}-upf-scaling"
    upf_pkg_rev=$(kpt alpha rpkg copy -n default $upf_deployment_pkg --workspace $ws | cut -d ' ' -f 1)
    echo "Copied to $upf_pkg_rev, pulling"

    rm -rf $ws
    kpt alpha rpkg pull -n default "$upf_pkg_rev" $ws

    rm -rf /tmp/$ws
    cp -r $ws /tmp

    echo "Updating the capacity"

    kpt fn eval --image gcr.io/kpt-fn/search-replace:v0.2.0 $ws -- by-path='spec.maxUplinkThroughput' by-file-path='**/capacity.yaml' put-value=$new_capacity_value
    kpt fn eval --image gcr.io/kpt-fn/search-replace:v0.2.0 $ws -- by-path='spec.maxDownlinkThroughput' by-file-path='**/capacity.yaml' put-value=$new_capacity_value

    diff -r /tmp/$ws $ws || echo

    echo "Pushing update"
    kpt alpha rpkg push -n default "$upf_pkg_rev" $ws

    echo "Proposing update"
    kpt alpha rpkg propose -n default "$upf_pkg_rev"
    k8s_wait_exists "packagerev" "$upf_pkg_rev"

    echo "Approving update"
    kpt alpha rpkg approve -n default "$upf_pkg_rev"

    # Wait for the deployment to start with a new pod
    timeout=600
    found=""
    while [[ -z $found && $timeout -gt 0 ]]; do
        echo "$timeout: checking if new pod has deployed"
        upf_pod_id_scale=$(kubectl --kubeconfig $cluster_kubeconfig get pods -l name=upf-${cluster} -n free5gc-upf | grep upf | head -1 | cut -d ' ' -f 1)
        if [[ ! -z $upf_pod_id_scale && $upf_pod_id_scale != $upf_pod_id ]]; then
            found=$upf_pod_id_scale
        fi
        timeout=$((timeout - 5))
        if [[ -z $found && $timeout -gt 0 ]]; then
            sleep 5
        fi
    done

    if [[ -z $found ]]; then
        echo "Timed out waiting for new pod to deploy"
        exit 1
    fi

    # Verify pod actually reaches ready state
    k8s_wait_ready_replicas "deployment" "upf-${cluster}" "$cluster_kubeconfig" "free5gc-upf"

    echo "Getting CPU for $upf_pod_id_scale"
    after_scaling_cpu=$(k8s_get_first_container_requests $cluster_kubeconfig free5gc-upf $upf_pod_id_scale "cpu")

    echo "Getting Memory for $upf_pod_id_scale"
    after_scaling_memory=$(k8s_get_first_container_requests $cluster_kubeconfig free5gc-upf $upf_pod_id_scale "memory")

    echo "After Scaling (cpu=$after_scaling_cpu memory=$after_scaling_memory)"

    k8s_check_scale "UPF" "CPU" $current_cpu $after_scaling_cpu
    k8s_check_scale "UPF" "Memory" $current_memory $after_scaling_memory

done
