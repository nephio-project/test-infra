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
## TEST-NAME: Deploy free5gc-cp to regional workload cluster
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

k8s_apply "$kubeconfig" "$TESTDIR/003-network.yaml"

k8s_wait_ready "$kubeconfig" 600 "default" "packagevariant" "network"

## Apply the network topology
k8s_apply "$kubeconfig" "$TESTDIR/003-secret.yaml"

$E2EDIR/provision/hacks/network-topo.sh

k8s_apply "$kubeconfig" "$TESTDIR/003-network-topo.yaml"
regional_kubeconfig=$(k8s_get_capi_kubeconfig "$kubeconfig" "default" "regional")

upstream_pkg_rev=$(kpt alpha rpkg get --name free5gc-cp --revision v1 -o jsonpath='{.metadata.name}')
pkg_rev=$(kpt alpha rpkg clone -n default "$upstream_pkg_rev" --repository regional free5gc-cp | cut -f 1 -d ' ')

kpt alpha rpkg propose -n default "$pkg_rev"
sleep 5
kpt alpha rpkg approve -n default "$pkg_rev"

k8s_wait_exists "$regional_kubeconfig" 600 "free5gc-cp" "statefulset" "mongodb"

k8s_wait_ready_replicas "$regional_kubeconfig" 600 "free5gc-cp" "statefulset" "mongodb"
