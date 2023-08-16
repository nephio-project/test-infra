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
## TEST-NAME: Deploy ueransim to edge clusters
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

# Register a subscriber with free5gc

regional_kubeconfig=$(k8s_get_capi_kubeconfig "$kubeconfig" "default" "regional")
ip=$(kubectl --kubeconfig $regional_kubeconfig get node -o jsonpath='{.items[0].status.addresses[?(.type=="InternalIP")].address}')
port=$(kubectl --kubeconfig $regional_kubeconfig -n free5gc-cp get svc webui-service -o jsonpath='{.spec.ports[0].nodePort}')

curl -d "@${TESTDIR}/007-subscriber.json" -H 'Token: admin' -H 'Content-Type: application/json' "http://${ip}:${port}/api/subscriber/imsi-208930000000003/20893"

# Deploy UERANSIM to edge01

k8s_apply "$TESTDIR/007-edge01-ueransim.yaml"

k8s_wait_ready "$kubeconfig" 600 "default" "packagevariant" "edge01-ueransim"

edge01_kubeconfig=$(k8s_get_capi_kubeconfig "$kubeconfig" "default" "edge01")
k8s_wait_exists "deployment" "ueransimgnb-edge01" "$edge01_kubeconfig" "ueransim"
k8s_wait_exists "deployment" "ueransimue-edge01" "$edge01_kubeconfig" "ueransim"
k8s_wait_ready_replicas "$edge01_kubeconfig" 600 "ueransim" "deployment" "ueransimgnb-edge01"
k8s_wait_ready_replicas "$edge01_kubeconfig" 600 "ueransim" "deployment" "ueransimue-edge01"
ue_pod_name=$(kubectl --kubeconfig $edge01_kubeconfig get pods -n ueransim -l app=ueransim -l component=ue -o jsonpath='{.items[0].metadata.name}')

timeout=600
found=""
while [[ -z $found && $timeout -gt 0 ]]; do
    echo "$timeout: waiting for tunnel to be established"
    ip_a=$(k8s_exec $edge01_kubeconfig "ueransim" $ue_pod_name "ip address show")
    if [[ $ip_a == *"uesimtun0"* ]]; then
        found="yes"
    fi
    timeout=$((timeout - 5))
    if [[ -z $found && $timeout -gt 0 ]]; then
        sleep 5
    fi
done

if [[ -z $found ]]; then
    echo "Timed out waiting for tunnel"
    exit 1
fi

k8s_exec $edge01_kubeconfig "ueransim" $ue_pod_name "ping -I uesimtun0 -c 3 172.0.0.1"
