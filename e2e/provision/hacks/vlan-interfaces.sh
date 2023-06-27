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
for cluster in $(kubectl get cluster -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --sort-by=.metadata.name --kubeconfig "$kubeconfig"); do
    _kubeconfig=$(k8s_get_capi_kubeconfig "$kubeconfig" "default" "$cluster")
    worker=$(kubectl get nodes -l node-role.kubernetes.io/control-plane!= -o jsonpath='{range .items[*]}"{.metadata.name}"{"\n"}{end}' --kubeconfig "$_kubeconfig")
    echo docker exec $worker ip link add link eth1 name eth1.2 type vlan id 2
    echo docker exec $worker ip link add link eth1 name eth1.2 type vlan id 2 | /bin/bash
    echo docker exec $worker ip link add link eth1 name eth1.3 type vlan id 3
    echo docker exec $worker ip link add link eth1 name eth1.3 type vlan id 3 | /bin/bash
    echo docker exec $worker ip link add link eth1 name eth1.4 type vlan id 4
    echo docker exec $worker ip link add link eth1 name eth1.4 type vlan id 4 | /bin/bash
    echo docker exec $worker ip link set up eth1.2
    echo docker exec $worker ip link set up eth1.2 | /bin/bash
    echo docker exec $worker ip link set up eth1.3
    echo docker exec $worker ip link set up eth1.3 | /bin/bash
    echo docker exec $worker ip link set up eth1.4
    echo docker exec $worker ip link set up eth1.4 | /bin/bash
done
