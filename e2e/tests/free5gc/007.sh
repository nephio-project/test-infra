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

# shellcheck source=e2e/defaults.env
source "$E2EDIR/defaults.env"

# shellcheck source=e2e/lib/_utils.sh
source "${LIBDIR}/_utils.sh"

# shellcheck source=e2e/lib/k8s.sh
source "${LIBDIR}/k8s.sh"

# shellcheck source=e2e/lib/porch.sh
source "${LIBDIR}/porch.sh"

function _wait_for_uesimtun0 {
    kubeconfig="$1"
    pod_name="$2"

    info "waiting for tunnel to be established"
    timeout=600
    found=""
    while [[ $timeout -gt 0 ]]; do
        ip_a=$(k8s_exec "$kubeconfig" "ueransim" "$pod_name" "ip address show")
        if [[ $ip_a == *"uesimtun0"* ]]; then
            debug "timeout: $timeout"
            found="yes"
            break
        fi
        timeout=$((timeout - 5))
        sleep 5
    done
    debug "$(kubectl logs -n ueransim --kubeconfig "$kubeconfig" "$pod_name")"

    if [[ -z $found ]]; then
        k8s_exec "$kubeconfig" "ueransim" "$pod_name" "ip address show"
        for worker in $(sudo docker ps --filter "name=edge01-md*" --format "{{.Names}}"); do
            sudo docker exec "$worker" dmesg -l warn,err
        done
        error "Timed out waiting for tunnel"
    fi
}

# Get free5GC WebUI details
regional_kubeconfig=$(k8s_get_capi_kubeconfig "regional")
debug "regional_kubeconfig: $regional_kubeconfig"
ip=$(kubectl --kubeconfig "$regional_kubeconfig" get node -o jsonpath='{.items[0].status.addresses[?(.type=="InternalIP")].address}')
debug "ip: $ip"
port=$(kubectl --kubeconfig "$regional_kubeconfig" -n free5gc-cp get svc webui-service -o jsonpath='{.spec.ports[0].nodePort}')
debug "port: $port"

# Register a subscriber with free5gc
curl -v -d "@${TESTDIR}/007-subscriber.json" -H 'Token: admin' -H 'Content-Type: application/json' "http://${ip}:${port}/api/subscriber/imsi-208930000000003/20893"
# List existing subscribers
curl -s -X GET -H 'Token: admin' "http://${ip}:${port}/api/subscriber"

# Deploy UERANSIM to edge01
k8s_apply "$TESTDIR/007-edge01-ueransim.yaml"
k8s_wait_ready "packagevariant" "edge01-ueransim"
porch_wait_published_packagerev "ueransim" "edge01"
edge01_kubeconfig=$(k8s_get_capi_kubeconfig "edge01")
k8s_wait_ready_replicas "deployment" "ueransimgnb-edge01" "$edge01_kubeconfig" "ueransim"
k8s_wait_ready_replicas "deployment" "ueransimue-edge01" "$edge01_kubeconfig" "ueransim"
ue_pod_name=$(kubectl --kubeconfig "$edge01_kubeconfig" get pods -n ueransim -l app=ueransim -l component=ue -o jsonpath='{.items[0].metadata.name}')
debug "ue_pod_name: $ue_pod_name"

# Wait for uesimtun0 interface
_wait_for_uesimtun0 "$edge01_kubeconfig" "$ue_pod_name"

# Validate uesimtun0 connectivity
k8s_exec "$edge01_kubeconfig" "ueransim" "$ue_pod_name" "ping -I uesimtun0 -c 3 172.0.0.1"
