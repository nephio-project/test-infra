#!/bin/bash
#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2023, 2025 The Nephio Authors.
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
    local use_configsync=${2:-true}
    local kubeconfig=${3:-"$HOME/.kube/config"}

    k8s_wait_ready "cl" "$cluster"
    for machineset in $(kubectl get machineset -l cluster.x-k8s.io/cluster-name="$cluster" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --kubeconfig "$kubeconfig"); do
        k8s_wait_ready "machineset" "$machineset"
    done

    # Wait for package variants
    for pv in cluster kindnet local-path-provisioner multus repo vlanindex; do
        k8s_wait_exists "packagevariants" "${cluster}-$pv"
       
    done

    if [[ "$use_configsync" = true ]] ; then
        for pv in configsync rootsync; do
            k8s_wait_exists "packagevariants" "${cluster}-$pv"
        done
    fi

    # Wait for package exists
    _wait_for_user_repo "$cluster"

    # Wait for management packages exist
    for pkg in "" "-cluster" "-repo" "-vlanindex"; do
        kpt_wait_pkg "mgmt" "${cluster}${pkg}"
    done

    # Wait for management staging packages exist
    for pkg in kindnet local-path-provisioner multus; do
        kpt_wait_pkg "mgmt-staging" "${cluster}-$pkg"
    done

    if [[ "$use_configsync" = true ]] ; then
        for pkg in configsync rootsync; do
            kpt_wait_pkg "mgmt-staging" "${cluster}-$pkg"
        done
    fi

    # Wait for deployments and daemonsets readiness
    kubeconfig=$(k8s_get_capi_kubeconfig "$cluster")

    if [[ "$use_configsync" = true ]] ; then
        k8s_wait_ready_replicas "deployment" "otel-collector" "$kubeconfig" "config-management-monitoring"
        for deploy in config-management-operator reconciler-manager "root-reconciler-$cluster"; do
            k8s_wait_ready_replicas "deployment" "$deploy" "$kubeconfig" "config-management-system"
        done
    fi
    
    k8s_wait_ready_replicas "deployment" "local-path-provisioner" "$kubeconfig" "local-path-storage"
    k8s_wait_ready_replicas "daemonset" "kindnet" "$kubeconfig" "kube-system"
    k8s_wait_ready_replicas "daemonset" "kube-multus-ds" "$kubeconfig" "kube-system"
}