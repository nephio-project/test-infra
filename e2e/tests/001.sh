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

set -o pipefail
set -o errexit
set -o nounset
[[ "${DEBUG:-false}" != "true" ]] || set -o xtrace

export HOME=${HOME:-/home/ubuntu/}
export E2EDIR=${E2EDIR:-$HOME/test-infra/e2e}
export TESTDIR=${TESTDIR:-$E2EDIR/tests}
export LIBDIR=${LIBDIR:-$E2EDIR/lib}

source "${LIBDIR}/k8s.sh"

kubeconfig="$HOME/.kube/config"

workload_cluster_pkg_rev=$(kpt alpha rpkg get --name nephio-workload-cluster --revision v6 -o jsonpath='{.metadata.name}')
kpt alpha rpkg clone -n default "$workload_cluster_pkg_rev" --repository mgmt regional
regional_pkg_rev=$(kpt alpha rpkg get --name regional -o jsonpath='{.metadata.name}')

kpt alpha rpkg propose -n default "$regional_pkg_rev"
kpt alpha rpkg approve -n default "$regional_pkg_rev"

k8s_wait_exists "$kubeconfig" 600 "default" "workloadcluster" "regional"

k8s_wait_ready "$kubeconfig" 600 "default" "cluster" "regional"
