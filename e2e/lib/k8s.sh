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

# shellcheck source=e2e/lib/_utils.sh
source "${E2EDIR:-$HOME/test-infra/e2e}/lib/_utils.sh"

# k8s_apply() - Creates the resources in a given kubernetes cluster
function k8s_apply {
    local file=$1
    local kubeconfig=${2:-"$HOME/.kube/config"}

    [ -f $kubeconfig ] || error "Kubeconfig file doesn't exist"
    [ -f $file ] || error "Resources file doesn't exist"

    kubectl --kubeconfig $kubeconfig apply -f $file
}

# k8s_wait_exists() - Waits for the creation of a given kubernetes resource
function k8s_wait_exists {
    local resource_type=$1
    local resource_name=$2
    local kubeconfig=${3:-"$HOME/.kube/config"}
    local resource_namespace=${4:-default}
    local timeout=${5:-600}

    # should validate the params...
    [ -f $kubeconfig ] || error "Kubeconfig file doesn't exist"

    info "looking for $resource_type $resource_namespace/$resource_name using $kubeconfig"
    local found=""
    while [[ -z $found && $timeout -gt 0 ]]; do
        found=$(kubectl --kubeconfig $kubeconfig -n $resource_namespace get $resource_type $resource_name -o jsonpath='{.metadata.name}' --ignore-not-found)
        timeout=$((timeout - 5))
        if [[ -z $found && $timeout -gt 0 ]]; then
            sleep 5
        fi
    done
    debug "timeout: $timeout"

    if [[ $found != "$resource_name" ]]; then
        kubectl --kubeconfig $kubeconfig -n $resource_namespace get $resource_type
        error "Timed out waiting for $resource_type $resource_namespace/$resource_name"
    fi

    info "Found $resource_type $resource_namespace/$resource_name"
}

# k8s_wait_ready() - Waits for the readiness of a given kubernetes resource
function k8s_wait_ready {
    local resource_type=$1
    local resource_name=$2
    local kubeconfig=${3:-"$HOME/.kube/config"}
    local resource_namespace=${4:-default}
    local timeout=${5:-600}

    # should validate the params...
    [ -f $kubeconfig ] || error "Kubeconfig file doesn't exist"

    k8s_wait_exists "$@"

    info "checking readiness of $resource_type $resource_namespace/$resource_name using $kubeconfig"
    local ready=""
    while [[ $ready != "True" && $timeout -gt 0 ]]; do
        ready=$(kubectl --kubeconfig $kubeconfig -n $resource_namespace get $resource_type $resource_name -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' || echo)
        timeout=$((timeout - 5))
        if [[ $ready != "True" && $timeout -gt 0 ]]; then
            sleep 5
        fi
    done
    debug "status: $ready"
    debug "timeout: $timeout"

    if [[ $ready != "True" ]]; then
        kubectl --kubeconfig $kubeconfig -n $resource_namespace describe $resource_type $resource_name
        error "Timed out waiting for $resource_type $resource_namespace/$resource_name to be ready"
    fi

    info "$resource_type $resource_namespace/$resource_name is ready"
}

# k8s_wait_ready_replicas() - Waits for the readiness of a minimun number of replicas
function k8s_wait_ready_replicas {
    local resource_type=$1
    local resource_name=$2
    local kubeconfig=${3:-"$HOME/.kube/config"}
    local resource_namespace=${4:-default}
    local timeout=${5:-600}
    local min_ready=${6:-1}

    # should validate the params...
    [ -f $kubeconfig ] || error "Kubeconfig file doesn't exist"

    k8s_wait_exists "$resource_type" "$resource_name" "$kubeconfig" "$resource_namespace" "$timeout"

    info "checking readiness of $resource_type $resource_namespace/$resource_name using $kubeconfig"
    local ready=""
    while [[ $ready -lt $min_ready && $timeout -gt 0 ]]; do
        ready=$(kubectl --kubeconfig $kubeconfig -n $resource_namespace get $resource_type $resource_name -o jsonpath='{.status.readyReplicas}' || echo)
        timeout=$((timeout - 5))
        if [[ $ready -lt $min_ready && $timeout -gt 0 ]]; then
            sleep 5
        fi
    done
    debug "status: $ready (want $min_ready)"
    debug "timeout: $timeout"

    if [[ $ready -lt $min_ready ]]; then
        kubectl --kubeconfig $kubeconfig -n $resource_namespace describe $resource_type $resource_name
        error "Timed out waiting for $resource_type $resource_namespace/$resource_name to be ready"
    fi

    info "$resource_type $resource_namespace/$resource_name is ready"
}

# k8s_get_capi_kubeconfig() - Gets the Kubeconfig file for a given Cluster API cluster
function k8s_get_capi_kubeconfig {
    local cluster=$1

    # mktemp is supported on both ubuntu and fedora
    local file=$(mktemp --suffix "_kubeconfig-$cluster")
    k8s_wait_exists "secret" "${cluster}-kubeconfig" >/dev/null 2>&1
    kubectl --kubeconfig "$HOME/.kube/config" get secret "${cluster}-kubeconfig" -o jsonpath='{.data.value}' | base64 -d >"$file"
    echo "$file"
}

# k8s_exec() - Execute a command into a pod container
function k8s_exec {
    local kubeconfig=$1
    local resource_namespace=$2
    local resource_name=$3
    local command=$4

    info "executing command $command on $resource_name in namespace $resource_namespace using $kubeconfig"
    kubectl --kubeconfig $kubeconfig -n $resource_namespace exec $resource_name -- /bin/bash -c "$command"
    return $?
}

function _k8s_absolute_unit {
    local value=$1

    # See https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
    if [[ $value == *m* ]]; then
        echo "${value//m/} * 0.001" | bc
    else
        echo "$value" | numfmt --from auto
    fi
}

# k8s_check_scale() - Validate scaling pod resources
function k8s_check_scale {
    local NF=$1
    local metric=$2
    local previous_raw=$3
    local current_raw=$4

    local current_scaled=$(_k8s_absolute_unit $4)
    local previous_scaled=$(_k8s_absolute_unit $3)
    local success=$(echo "$previous_scaled < $current_scaled" | bc)

    info "Current : $current_raw ($current_scaled), Previous: $previous_raw ($previous_scaled)"
    info "$NF - Comparing the new $metric after scaling"
    if [ "$success" == "0" ]; then
        error "$NF $metric scaling Failed"
    fi
    info "$NF - $metric Pod Scaling Successful"
}

# k8s_get_first_container_requests() - Get request value from the first container found in the pod
function k8s_get_first_container_requests {
    local kubeconfig=$1
    local namespace=$2
    local pod_id=$3
    local resource_type=$4

    kubectl --kubeconfig $kubeconfig get pods $pod_id -n $namespace -o jsonpath="{.spec.containers[0].resources.requests.$resource_type}"
}

# k8s_get_newest_pod_name() - Get most recent pod name
function k8s_get_newest_pod_name {
    local kubeconfig="$1"
    local label="$2"
    local namespace="$3"
    local previous_podname="${4:-}"

    # Wait for the deployment to start with a new pod
    timeout=600
    while [[ $timeout -gt 0 ]]; do
        podname=$(kubectl --kubeconfig "$kubeconfig" get pods -l "$label" -n "$namespace" --field-selector=status.phase==Running -o jsonpath='{.items[0].metadata.name}')
        if [[ $podname != "$previous_podname" ]]; then
            echo "$podname"
            return
        fi
        timeout=$((timeout - 5))
        sleep 5
    done

    kubectl --kubeconfig "$kubeconfig" get pods -n "$namespace" --show-labels
    kubectl --kubeconfig "$kubeconfig" get events -n "$namespace"
    error "Timed out waiting for new pod to deploy"
}
