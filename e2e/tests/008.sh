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
## Usage : 008.sh <Capacity> , Capacity>5G

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

for cluster in "edge01" "edge02"; do

    upf_deployment_pkg=$(kpt alpha rpkg get -n default --name free5gc-upf | grep packagevariant | grep $cluster | grep true | cut -d ' ' -f 1)

    upf_pkg_rev=$(kpt alpha rpkg copy -n default $upf_deployment_pkg --workspace ${cluster}_upf_scaling | cut -d ' ' -f 1)

    kpt alpha rpkg pull -n default "$upf_pkg_rev" ${cluster}_upf_scaling

    kpt fn eval --image gcr.io/kpt-fn/search-replace:v0.2.0 ${cluster}_upf_scaling -- by-path='spec.maxUplinkThroughput' by-file-path='**/capacity.yaml' put-value=$new_capacity_value
    kpt fn eval --image gcr.io/kpt-fn/search-replace:v0.2.0 ${cluster}_upf_scaling -- by-path='spec.maxDownlinkThroughput' by-file-path='**/capacity.yaml' put-value=$new_capacity_value

    kpt alpha rpkg push -n default "$upf_pkg_rev" ${cluster}_upf_scaling

    kpt alpha rpkg propose -n default "$upf_pkg_rev"

    kpt alpha rpkg approve -n default "$upf_pkg_rev"

    cluster_kubeconfig=$(k8s_get_capi_kubeconfig "$kubeconfig" "default" "$cluster")

    k8s_wait_exists "$cluster-kubeconfig" 600 "free5gc" "deployment" "free5gc-upf"

    k8s_wait_ready "$cluster-kubeconfig" 600 "free5gc" "deployment" "free5gc-upf"
done
