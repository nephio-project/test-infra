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

# shellcheck source=e2e/lib/k8s.sh
source "${E2EDIR:-$HOME/test-infra/e2e}/lib/k8s.sh"
# shellcheck source=e2e/lib/kpt.sh
source "${E2EDIR:-$HOME/test-infra/e2e}/lib/kpt.sh"

# capi_cluster_ready() - Wait for Cluster API cluster service readiness
function capi_cluster_ready {
    local cluster=$1
    local kubeconfig=${2:-"$HOME/.kube/config"}

    k8s_wait_ready "cl" "$cluster"
    for machineset in $(kubectl get machineset -l cluster.x-k8s.io/cluster-name="$cluster" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --kubeconfig "$kubeconfig"); do
        k8s_wait_ready "machineset" "$machineset"
    done

    # Use Docker local registry to reduce external traffic
    if [ "$(docker container inspect -f '{{.State.Running}}' docker_registry_proxy)" = "true" ]; then
        _kubeconfig=$(k8s_get_capi_kubeconfig "$cluster")
        pids=""
        for node in $(kubectl get nodes -l node-role.kubernetes.io/control-plane!= -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --kubeconfig "$_kubeconfig"); do
            docker exec "$node" sh -c "curl http://$(hostname -i):3128/setup/systemd | sed s/docker\.service/containerd\.service/g \
  | sed '/Environment/ s/$/ \"NO_PROXY=127.0.0.0\/8,10.0.0.0\/8,172.16.0.0\/12,192.168.0.0\/16\"/' | bash" &
            pids="$pids $!"
        done
        wait $pids
    fi

    # Wait for package variants
    for pv in cluster configsync kindnet local-path-provisioner multus repo rootsync vlanindex; do
        k8s_wait_exists "packagevariants" "${cluster}-$pv"
    done

    # Wait for package exists
    _wait_for_user_repo "$cluster"

    # Wait for management packages exist
    for pkg in "" "-cluster" "-repo" "-vlanindex"; do
        kpt_wait_pkg "mgmt" "${cluster}${pkg}"
    done

    # Wait for management staging packages exist
    for pkg in configsync kindnet local-path-provisioner multus rootsync; do
        kpt_wait_pkg "mgmt-staging" "${cluster}-$pkg"
    done

    # Wait for deployments and daemonsets readiness
    kubeconfig=$(k8s_get_capi_kubeconfig "$cluster")
    k8s_wait_ready_replicas "deployment" "otel-collector" "$kubeconfig" "config-management-monitoring"
    for deploy in config-management-operator reconciler-manager "root-reconciler-$cluster"; do
        k8s_wait_ready_replicas "deployment" "$deploy" "$kubeconfig" "config-management-system"
    done
    k8s_wait_ready_replicas "deployment" "local-path-provisioner" "$kubeconfig" "local-path-storage"
    k8s_wait_ready_replicas "daemonset" "kindnet" "$kubeconfig" "kube-system"
    k8s_wait_ready_replicas "daemonset" "kube-multus-ds" "$kubeconfig" "kube-system"
}
