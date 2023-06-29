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

function k8s_apply {
    local kubeconfig=$1
    local file=$2

    # should validate the params...

    kubectl --kubeconfig $kubeconfig apply -f $file
}

function k8s_wait_exists {
    local kubeconfig=$1
    local timeout=$2
    local resource_namespace=$3
    local resource_type=$4
    local resource_name=$5

    # should validate the params...

    local found=""
    while [[ -z $found && $timeout -gt 0 ]]; do
        echo "$timeout: looking for $resource_type $resource_namespace/$resource_name using $kubeconfig"
        found=$(kubectl --kubeconfig $kubeconfig -n $resource_namespace get $resource_type $resource_name -o jsonpath='{.metadata.name}' || echo)
        timeout=$((timeout - 5))
        if [[ -z $found && $timeout -gt 0 ]]; then
            sleep 5
        fi
    done

    if [[ $found != "$resource_name" ]]; then
        echo "Timed out waiting for $resource_type $resource_namespace/$resource_name"
        return 1
    fi

    echo "Found $resource_type $resource_namespace/$resource_name"
    return 0
}

function k8s_wait_ready {
    local kubeconfig=$1
    local timeout=$2
    local resource_namespace=$3
    local resource_type=$4
    local resource_name=$5

    # should validate the params...

    local ready=""
    while [[ $ready != "True" && $timeout -gt 0 ]]; do
        echo "$timeout: checking readiness of $resource_type $resource_namespace/$resource_name using $kubeconfig"
        ready=$(kubectl --kubeconfig $kubeconfig -n $resource_namespace get $resource_type $resource_name -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' || echo)
        timeout=$((timeout - 5))
        if [[ $ready != "True" && $timeout -gt 0 ]]; then
            echo "status: $ready"
            sleep 5
        fi
    done

    if [[ $ready != "True" ]]; then
        echo "Timed out waiting for $resource_type $resource_namespace/$resource_name to be ready"
        return 1
    fi

    echo "$resource_type $resource_namespace/$resource_name is ready"
    return 0
}

function k8s_wait_ready_replicas {
    local kubeconfig=$1
    local timeout=$2
    local resource_namespace=$3
    local resource_type=$4
    local resource_name=$5
    local min_ready=${6:-1}

    # should validate the params...

    local ready=""
    while [[ $ready -lt $min_ready && $timeout -gt 0 ]]; do
        echo "$timeout: checking readiness of $resource_type $resource_namespace/$resource_name using $kubeconfig"
        ready=$(kubectl --kubeconfig $kubeconfig -n $resource_namespace get $resource_type $resource_name -o jsonpath='{.status.readyReplicas}' || echo)
        timeout=$((timeout - 5))
        if [[ $ready -lt $min_ready && $timeout -gt 0 ]]; then
            echo "status: $ready (want $min_ready)"
            sleep 5
        fi
    done

    if [[ $ready -lt $min_ready ]]; then
        echo "Timed out waiting for $resource_type $resource_namespace/$resource_name to be ready"
        return 1
    fi

    echo "$resource_type $resource_namespace/$resource_name is ready"
    return 0
}

function k8s_get_capi_kubeconfig {
    local kubeconfig=$1
    local namespace=$2
    local cluster=$3

    local file=$(tempfile --prefix "kubeconfig-$cluster-")
    k8s_wait_exists "$kubeconfig" 600 "$namespace" "secret" "${cluster}-kubeconfig" >/dev/null 2>&1
    kubectl --kubeconfig "$kubeconfig" -n "$namespace" get secret "${cluster}-kubeconfig" -o jsonpath='{.data.value}' | base64 -d >"$file"
    echo "$file"
}

function k8s_exec {
    local kubeconfig=$1
    local resource_namespace=$2
    local resource_name=$3
    local command=$4

    echo "executing command $command on $resource_name in namespace $resource_namespace using $kubeconfig"
    kubectl --kubeconfig $kubeconfig -n $resource_namespace exec $resource_name -- /bin/bash -c "$command"
    return $?
}

function _k8s_quantity_factor {
    local value=$1
    local factor=1

    # See https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
    if [[ $value == *Ki* ]]; then
        factor=1024
    elif [[ $value == *Mi* ]]; then
        factor=$(expr 1024 '*' 1024)
    elif [[ $value == *Gi* ]]; then
        factor=$(expr 1024 '*' 1024 '*' 1024)
    elif [[ $value == *Ti* ]]; then
        factor=$(expr 1024 '*' 1024 '*' 1024 '*' 1024)
    elif [[ $value == *Pi* ]]; then
        factor=$(expr 1024 '*' 1024 '*' 1024 '*' 1024 '*' 1024)
    elif [[ $value == *Ei* ]]; then
        factor=$(expr 1024 '*' 1024 '*' 1024 '*' 1024 '*' 1024 '*' 1024)
    elif [[ $value == *K* ]]; then
        factor=1000
    elif [[ $value == *M* ]]; then
        factor=$(expr 1000 '*' 1000)
    elif [[ $value == *G* ]]; then
        factor=$(expr 1000 '*' 1000 '*' 1000)
    elif [[ $value == *T* ]]; then
        factor=$(expr 1000 '*' 1000 '*' 1000 '*' 1000)
    elif [[ $value == *P* ]]; then
        factor=$(expr 1000 '*' 1000 '*' 1000 '*' 1000 '*' 1000)
    elif [[ $value == *E* ]]; then
        factor=$(expr 1000 '*' 1000 '*' 1000 '*' 1000 '*' 1000 '*' 1000)
    elif [[ $value == *m* ]]; then
        factor="0.001"
    fi

    echo $factor
}

function k8s_check_scale {
    local NF=$1
    local metric=$2
    local previous_raw=$3
    local current_raw=$4

    local current_factor=$(_k8s_quantity_factor $current_raw)
    local previous_factor=$(_k8s_quantity_factor $previous_raw)

    local current=$(echo "$current_raw" | tr -d '[a-zA-Z]')
    local previous=$(echo "$previous_raw" | tr -d '[a-zA-Z]')

    local current_scaled=$(echo "$current * $current_factor" | bc)
    local previous_scaled=$(echo "$previous * $previous_factor" | bc)
    local success=$(echo "$previous_scaled < $current_scaled" | bc)

    echo "Current : $current_raw ($current_scaled), Previous: $previous_raw ($previous_scaled)"
    echo "$NF - Comparing the new $metric after scaling"
    if [ "$success" == "0" ]; then
        echo "$NF $metric scaling Failed"
        exit 1
    fi
    echo "$NF - $metric Pod Scaling Successful"
}

function k8s_get_first_container_cpu_requests {
    local kubeconfig=$1
    local namespace=$2
    local pod_id=$3

    kubectl --kubeconfig $kubeconfig get pods $pod_id -n $namespace -o jsonpath='{.spec.containers[0].resources.requests.cpu}'
}

function k8s_get_first_container_memory_requests {
    local kubeconfig=$1
    local namespace=$2
    local pod_id=$3

    kubectl --kubeconfig $kubeconfig get pods $pod_id -n $namespace -o jsonpath='{.spec.containers[0].resources.requests.memory}'
}
