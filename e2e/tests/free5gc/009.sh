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
## TEST-NAME: Vertically Scale free5gc SMF in Regional Clusters
## Usage : 009.sh <maxSessions, maxNFConnections> , maxSessions > 2000, maxNFConnections > 20

set -o pipefail
set -o errexit
set -o nounset
[[ ${DEBUG:-false} != "true" ]] || set -o xtrace

# shellcheck source=e2e/defaults.env
source "$E2EDIR/defaults.env"

# shellcheck source=e2e/lib/_utils.sh
source "${LIBDIR}/_utils.sh"

# shellcheck source=e2e/lib/k8s.sh
source "${LIBDIR}/k8s.sh"

kubeconfig="$HOME/.kube/config"

#Get the cluster kubeconfig
info "Getting kubeconfig for regional"
cluster_kubeconfig=$(k8s_get_capi_kubeconfig "regional")
debug "cluster_kubeconfig: $cluster_kubeconfig"

# Get current SMF pod state before scaling
k8s_wait_ready_replicas "deployment" "smf-regional" "$cluster_kubeconfig" "free5gc-cp"
info "Getting pod for SMF in cluster regional"
smf_pod_id=$(k8s_get_newest_pod_name "$cluster_kubeconfig" "name=smf-regional" "free5gc-cp")
debug "smf_pod_id: $smf_pod_id"
current_cpu=$(k8s_get_first_container_requests "$cluster_kubeconfig" free5gc-cp "$smf_pod_id" "cpu")
debug "current_cpu: $current_cpu"
current_memory=$(k8s_get_first_container_requests "$cluster_kubeconfig" free5gc-cp "$smf_pod_id" "memory")
debug "current_memory: $current_memory"

# Scale the SMF pod
k8s_wait_exists "packagevariant" "regional-free5gc-smf-regional-free5gc-smf"
smf_deployment_pkg=$(kubectl --kubeconfig "$kubeconfig" get packagevariant regional-free5gc-smf-regional-free5gc-smf -o jsonpath='{.status.downstreamTargets[0].name}')

#if it's already a Draft, we will edit it directly, otherwise we will create a copy
k8s_wait_exists "packagerevision" "$smf_deployment_pkg"
lifecycle=$(kubectl --kubeconfig "$kubeconfig" get packagerevision "$smf_deployment_pkg" -o jsonpath='{.spec.lifecycle}')
ws="regional-smf-scaling"

smf_pkg_rev=$smf_deployment_pkg

if [[ $lifecycle == "Published" ]]; then
    info "Copying $smf_deployment_pkg"
    smf_pkg_rev=$(porchctl rpkg copy -n default "$smf_deployment_pkg" --workspace "$ws" | cut -d ' ' -f 1)
    info "Copied to $smf_pkg_rev, pulling"
fi

# We need to put this entire section in a retry loop, because it is possible
# for a controller to come in and change the package after we pull it. This
# in general is something we should not be seeing, but is not really a failure
# state, so we will work around it in here. A separate issues has been filed to
# debug why a controller is unexpectedly changing the package.

retries=5
while [[ $retries -gt 0 ]]; do
    rm -rf $ws
    porchctl rpkg pull -n default "$smf_pkg_rev" $ws

    rm -rf /tmp/$ws
    cp -r $ws /tmp

    info "Updating the capacity"

    kpt fn eval --image gcr.io/kpt-fn/search-replace:v0.2.0 $ws -- by-path='spec.maxSessions' by-file-path='**/capacity.yaml' put-value=10000
    kpt fn eval --image gcr.io/kpt-fn/search-replace:v0.2.0 $ws -- by-path='spec.maxNFConnections' by-file-path='**/capacity.yaml' put-value=50

    diff -r /tmp/$ws $ws || echo

    modified=false
    info "Pushing update"
    output=$(porchctl rpkg push -n default "$smf_pkg_rev" $ws 2>&1)
    if [[ $output =~ "modified" ]]; then
        modified=true
    fi

    if [[ $modified == false ]]; then
        info "Proposing update"
        output=$(porchctl rpkg propose -n default "$smf_pkg_rev" 2>&1)
        if [[ $output =~ "modified" ]]; then
            modified=true
        else
            k8s_wait_exists "packagerev" "$smf_pkg_rev"
        fi
    fi

    if [[ $modified == false ]]; then
        info "Approving update"
        output=$(porchctl rpkg approve -n default "$smf_pkg_rev" 2>&1)
        if [[ $output =~ "modified" ]]; then
            modified=true
        fi
    fi

    if [[ $modified == false ]]; then
        retries=0
    else
        info "Capacity update failed due to concurrent change, retrying"
        retries=$((retries - 1))
    fi
done

# Get current SMF pod state after scaling
k8s_wait_ready_replicas "deployment" "smf-regional" "$cluster_kubeconfig" "free5gc-cp"
info "Get newest SMF pod"
smf_pod_id_scale=$(k8s_get_newest_pod_name "$cluster_kubeconfig" "name=smf-regional" "free5gc-cp" "$smf_pod_id")
debug "smf_pod_id_scale: $smf_pod_id_scale"
after_scaling_cpu=$(k8s_get_first_container_requests "$cluster_kubeconfig" free5gc-cp "$smf_pod_id_scale" "cpu")
debug "after_scaling_cpu: $after_scaling_cpu"
after_scaling_memory=$(k8s_get_first_container_requests "$cluster_kubeconfig" free5gc-cp "$smf_pod_id_scale" "memory")
debug "after_scaling_memory: $after_scaling_memory"

# Validate scale CPU and memory resources
info "Validate scale CPU and memory SMF resources"
k8s_check_scale "SMF" "CPU" "$current_cpu" "$after_scaling_cpu"
k8s_check_scale "SMF" "Memory" "$current_memory" "$after_scaling_memory"
