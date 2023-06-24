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


function _check_scale {
    local metric=$1
    local previous=$2
    local current=$3
    
    echo "UPF - Comparing the new $metric after scaling"
    if [ "$previous" -le  "$current" ]; then
        echo "UPF $metric scaling Failed"
        exit 1
    fi
    echo "UPF - $metric Pod Scaling Successful"
}


for cluster in "edge01" "edge02"; do

    #Get the cluster kubeconfig
    cluster_kubeconfig=$(k8s_get_capi_kubeconfig "$kubeconfig" "default" "$cluster")
    
    #Before scaling test get the running UPF POD ID
    upf_pod_id=$(kubectl --kubeconfig $cluster_kubeconfig get pods -l app=free5gc-upf -l nf=upf -n free5gc-upf | grep upf | cut -d ' ' -f 1)

    if [ -z "$upf_pod_id" ]; then
    	echo "UPF PoD Not Found"
    	exit 1
    fi

    #If the pod exists, Get the current CPU and Memory limit
    current_cpu=$(kubectl --kubeconfig $cluster_kubeconfig get pods -l app=free5gc-upf -l nf=upf -n free5gc-upf -o jsonpath='{range .items[*].spec.containers[*]}{.resources.requests.cpu}{"\n"}{end}' |sed 's/m$//') 

    current_memory=$(kubectl --kubeconfig $cluster_kubeconfig get pods -l app=free5gc-upf -l nf=upf -n free5gc-upf -o jsonpath='{range .items[*].spec.containers[*]}{.resources.requests.memory}{"\n"}{end}' |sed 's/Mi$//')
    
    echo "Current CPU $current_cpu"
    echo "Current Memory $current_memory"

    #Scale the POD
    upf_deployment_pkg=$(kpt alpha rpkg get -n default --name free5gc-upf | grep packagevariant | grep $cluster | grep true | cut -d ' ' -f 1)

    upf_pkg_rev=$(kpt alpha rpkg copy -n default $upf_deployment_pkg --workspace ${cluster}_upf_scaling | cut -d ' ' -f 1)

    kpt alpha rpkg pull -n default "$upf_pkg_rev" ${cluster}_upf_scaling

    kpt fn eval --image gcr.io/kpt-fn/search-replace:v0.2.0 ${cluster}_upf_scaling -- by-path='spec.maxUplinkThroughput' by-file-path='**/capacity.yaml' put-value=$new_capacity_value
    kpt fn eval --image gcr.io/kpt-fn/search-replace:v0.2.0 ${cluster}_upf_scaling -- by-path='spec.maxDownlinkThroughput' by-file-path='**/capacity.yaml' put-value=$new_capacity_value

    kpt alpha rpkg push -n default "$upf_pkg_rev" ${cluster}_upf_scaling

    kpt alpha rpkg propose -n default "$upf_pkg_rev"

    kpt alpha rpkg approve -n default "$upf_pkg_rev"


    k8s_wait_exists "$cluster-kubeconfig" 600 "free5gc" "deployment" "free5gc-upf"

    k8s_wait_ready "$cluster-kubeconfig" 600 "free5gc" "deployment" "free5gc-upf"

    #Get the new POD ID
    upf_pod_id_scale=$(kubectl --kubeconfig $cluster_kubeconfig get pods -l app=free5gc-upf -l nf=upf -n free5gc-upf | grep upf | cut -d ' ' -f 1)

    if [ -z "$upf_pod_id_scale" ]; then
    	echo "UPF PoD afer Scaling Not Found"
    	exit 1
    fi
    
    after_scaling_cpu=$(kubectl --kubeconfig $cluster_kubeconfig get pods -l app=free5gc-upf -l nf=upf -n free5gc-upf -o jsonpath='{range .items[*].spec.containers[*]}{.resources.requests.cpu}{"\n"}{end}' |sed 's/m$//') 

    after_scaling_memory=$(kubectl --kubeconfig $cluster_kubeconfig get pods -l app=free5gc-upf -l nf=upf -n free5gc-upf -o jsonpath='{range .items[*].spec.containers[*]}{.resources.requests.memory}{"\n"}{end}' |sed 's/Mi$//')

    echo "After Scaling  $after_scaling_cpu $after_scaling_memory"

   _check_scale "CPU" $current_cpu $after_scaling_cpu
   _check_scale "Memory" $current_memory $after_scaling_memory

done
