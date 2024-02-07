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

# shellcheck source=e2e/defaults.env
source "$E2EDIR/defaults.env"

# shellcheck source=e2e/lib/_utils.sh
source "${LIBDIR}/_utils.sh"

# shellcheck source=e2e/lib/k8s.sh
source "${LIBDIR}/k8s.sh"

kubeconfig="$HOME/.kube/config"
# Set the new value for maxUplinkThroughput as a parameter
new_capacity_value=${1:-20G}

#Get the cluster kubeconfig
info "Getting kubeconfig for edge01"
cluster_kubeconfig=$(k8s_get_capi_kubeconfig "edge01")
debug "cluster_kubeconfig: $cluster_kubeconfig"

# Get current UPF pod state before scaling
k8s_wait_ready_replicas "deployment" "upf-edge01" "$cluster_kubeconfig" "free5gc-upf"
info "Getting pod for UPF in cluster edge01"
upf_pod_id=$(k8s_get_newest_pod_name "$cluster_kubeconfig" "name=upf-edge01" "free5gc-upf")
debug "upf_pod_id: $upf_pod_id"
current_cpu=$(k8s_get_first_container_requests "$cluster_kubeconfig" free5gc-upf "$upf_pod_id" "cpu")
debug "current_cpu: $current_cpu"
current_memory=$(k8s_get_first_container_requests "$cluster_kubeconfig" free5gc-upf "$upf_pod_id" "memory")
debug "current_memory: $current_memory"

# Scale the UPF pod
upf_deployment_pkg=$(kubectl --kubeconfig "$kubeconfig" get packagevariant edge-free5gc-upf-edge01-free5gc-upf -o jsonpath='{.status.downstreamTargets[0].name}')
info "Copying $upf_deployment_pkg"
ws="edge01-upf-scaling"
upf_pkg_rev=$(porchctl rpkg copy -n default "$upf_deployment_pkg" --workspace "$ws" | cut -d ' ' -f 1)
info "Copied to $upf_pkg_rev, pulling"

rm -rf $ws
porchctl rpkg pull -n default "$upf_pkg_rev" $ws

rm -rf /tmp/$ws
cp -r $ws /tmp

info "Updating the capacity"
kpt fn eval --image gcr.io/kpt-fn/search-replace:v0.2.0 "$ws" -- by-path='spec.maxUplinkThroughput' by-file-path='**/capacity.yaml' put-value="$new_capacity_value"
kpt fn eval --image gcr.io/kpt-fn/search-replace:v0.2.0 "$ws" -- by-path='spec.maxDownlinkThroughput' by-file-path='**/capacity.yaml' put-value="$new_capacity_value"

diff -r /tmp/$ws $ws || echo

info "Pushing $upf_pkg_rev update"
porchctl rpkg push -n default "$upf_pkg_rev" $ws

info "Proposing $upf_pkg_rev update"
porchctl rpkg propose -n default "$upf_pkg_rev"
k8s_wait_exists "packagerev" "$upf_pkg_rev"

info "Approving $upf_pkg_rev update"
porchctl rpkg approve -n default "$upf_pkg_rev"

# Get current UPF pod state after scaling
k8s_wait_ready_replicas "deployment" "upf-edge01" "$cluster_kubeconfig" "free5gc-upf"
info "Get newest UPF pod"
upf_pod_id_scale=$(k8s_get_newest_pod_name "$cluster_kubeconfig" "name=upf-edge01" "free5gc-upf" "$upf_pod_id")
debug "upf_pod_id_scale: $upf_pod_id_scale"
after_scaling_cpu=$(k8s_get_first_container_requests "$cluster_kubeconfig" free5gc-upf "$upf_pod_id_scale" "cpu")
debug "after_scaling_cpu: $after_scaling_cpu"
after_scaling_memory=$(k8s_get_first_container_requests "$cluster_kubeconfig" free5gc-upf "$upf_pod_id_scale" "memory")
debug "after_scaling_memory: $after_scaling_memory"

# Validate scale CPU and memory resources
info "Validate scale CPU and memory UPF resources"
k8s_check_scale "UPF" "CPU" "$current_cpu" "$after_scaling_cpu"
k8s_check_scale "UPF" "Memory" "$current_memory" "$after_scaling_memory"
