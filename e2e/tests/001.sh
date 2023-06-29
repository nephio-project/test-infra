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
## TEST-NAME: Deploy regional workload cluster
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

workload_cluster_pkg_rev=$(kpt alpha rpkg get --name nephio-workload-cluster --revision v8 -o jsonpath='{.metadata.name}')
regional_pkg_rev=$(kpt alpha rpkg clone -n default "$workload_cluster_pkg_rev" --repository mgmt regional | cut -f 1 -d ' ')

kpt alpha rpkg pull -n default "$regional_pkg_rev" regional
kpt fn eval --image "gcr.io/kpt-fn/set-labels:v0.2.0" regional -- "nephio.org/site-type=regional" "nephio.org/region=us-west1"
kpt alpha rpkg push -n default "$regional_pkg_rev" regional

kpt alpha rpkg propose -n default "$regional_pkg_rev"
k8s_wait_exists "$kubeconfig" 600 "default" "packagerev" "$regional_pkg_rev"
kpt alpha rpkg approve -n default "$regional_pkg_rev"

k8s_wait_exists "$kubeconfig" 600 "default" "workloadcluster" "regional"
k8s_wait_exists "$kubeconfig" 600 "default" "cluster" "regional"
k8s_wait_ready "$kubeconfig" 600 "default" "cluster" "regional"
