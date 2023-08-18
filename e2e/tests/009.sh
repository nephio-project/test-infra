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

export HOME=${HOME:-/home/ubuntu/}
export E2EDIR=${E2EDIR:-$HOME/test-infra/e2e}
export TESTDIR=${TESTDIR:-$E2EDIR/tests}
export LIBDIR=${LIBDIR:-$E2EDIR/lib}

# shellcheck source=e2e/lib/_utils.sh
source "${LIBDIR}/_utils.sh"
# shellcheck source=e2e/lib/k8s.sh
source "${LIBDIR}/k8s.sh"

kubeconfig="$HOME/.kube/config"

#Get the cluster kubeconfig
info "Getting kubeconfig for regional"
cluster_kubeconfig=$(k8s_get_capi_kubeconfig "regional")

#Before scaling test get the running SMF POD ID
info "Getting pod for SMF in cluster regional"
smf_pod_id=$(kubectl --kubeconfig "$cluster_kubeconfig" get pods -l name=smf-regional -n free5gc-cp | grep smf | head -1 | cut -d ' ' -f 1)

if [ -z "$smf_pod_id" ]; then
    error "SMF Pod Not Found"
fi

info "Getting CPU for $smf_pod_id"
#If the pod exists, Get the current CPU and Memory limit
current_cpu=$(k8s_get_first_container_requests "$cluster_kubeconfig" free5gc-cp "$smf_pod_id" "cpu")
debug "current_cpu: $current_cpu"

info "Getting memory for $smf_pod_id"
current_memory=$(k8s_get_first_container_requests "$cluster_kubeconfig" free5gc-cp "$smf_pod_id" "memory")
debug "current_memory: $current_memory"

#Scale the POD
smf_deployment_pkg=$(kubectl --kubeconfig "$kubeconfig" get packagevariant regional-free5gc-smf-regional-free5gc-smf -o jsonpath='{.status.downstreamTargets[0].name}')

#if it's already a Draft, we will edit it directly, otherwise we will create a copy
lifecycle=$(kubectl --kubeconfig "$kubeconfig" get packagerevision "$smf_deployment_pkg" -o jsonpath='{.spec.lifecycle}')
ws="regional-smf-scaling"

smf_pkg_rev=$smf_deployment_pkg

if [[ $lifecycle == "Published" ]]; then
    info "Copying $smf_deployment_pkg"
    smf_pkg_rev=$(kpt alpha rpkg copy -n default "$smf_deployment_pkg" --workspace "$ws" | cut -d ' ' -f 1)
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
    kpt alpha rpkg pull -n default "$smf_pkg_rev" $ws

    rm -rf /tmp/$ws
    cp -r $ws /tmp

    info "Updating the capacity"

    kpt fn eval --image gcr.io/kpt-fn/search-replace:v0.2.0 $ws -- by-path='spec.maxSessions' by-file-path='**/capacity.yaml' put-value=10000
    kpt fn eval --image gcr.io/kpt-fn/search-replace:v0.2.0 $ws -- by-path='spec.maxNFConnections' by-file-path='**/capacity.yaml' put-value=50

    diff -r /tmp/$ws $ws || echo

    modified=false
    info "Pushing update"
    output=$(kpt alpha rpkg push -n default "$smf_pkg_rev" $ws >/dev/null 2>&1)
    if [[ $output =~ "modified" ]]; then
        modified=true
    fi

    if [[ $modified == false ]]; then
        info "Proposing update"
        output=$(kpt alpha rpkg propose -n default "$smf_pkg_rev" >/dev/null 2>&1)
        if [[ $output =~ "modified" ]]; then
            modified=true
        else
            k8s_wait_exists "packagerev" "$smf_pkg_rev"
        fi
    fi

    if [[ $modified == false ]]; then
        info "Approving update"
        output=$(kpt alpha rpkg approve -n default "$smf_pkg_rev" >/dev/null 2>&1)
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

# Wait for the deployment to start with a new pod
info "checking if new pod has deployed"
timeout=600
found=""
while [[ -z $found && $timeout -gt 0 ]]; do
    debug "timeout: $timeout"
    smf_pod_id_scale=$(kubectl --kubeconfig "$cluster_kubeconfig" get pods -l name=smf-regional -n free5gc-cp | grep smf | head -1 | cut -d ' ' -f 1)
    if [[ -n $smf_pod_id_scale && $smf_pod_id_scale != "$smf_pod_id" ]]; then
        found=$smf_pod_id_scale
    fi
    timeout=$((timeout - 5))
    if [[ -z $found && $timeout -gt 0 ]]; then
        sleep 5
    fi
done

if [[ -z $found ]]; then
    error "Timed out waiting for new pod to deploy"
fi

# Verify pod actually reaches ready state
k8s_wait_ready_replicas "deployment" "smf-regional" "$cluster_kubeconfig" "free5gc-cp"

info "Getting CPU for $smf_pod_id_scale"
after_scaling_cpu=$(k8s_get_first_container_requests "$cluster_kubeconfig" free5gc-cp "$smf_pod_id_scale" "cpu")

info "Getting Memory for $smf_pod_id_scale"
after_scaling_memory=$(k8s_get_first_container_requests "$cluster_kubeconfig" free5gc-cp "$smf_pod_id_scale" "memory")

info "After Scaling  $after_scaling_cpu $after_scaling_memory"

k8s_check_scale "SMF" "CPU" "$current_cpu" "$after_scaling_cpu"
k8s_check_scale "SMF" "Memory" "$current_memory" "$after_scaling_memory"
