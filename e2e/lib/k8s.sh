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
  while [[ -z "$found" && $timeout -gt 0 ]]
  do
    echo "$timeout: looking for $resource_type $resource_namespace/$resource_name using $kubeconfig"
    found=$(kubectl --kubeconfig $kubeconfig -n $resource_namespace get $resource_type $resource_name -o jsonpath='{.metadata.name}' || echo)
    timeout=$(( $timeout - 5 ))
    if [[ -z "$found" && $timeout -gt 0 ]]; then
      sleep 5
    fi
  done

  if [[ "$found" != "$resource_name" ]]; then
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
  while [[ "$ready" != "True" && $timeout -gt 0 ]]
  do
    echo "$timeout: checking readiness of $resource_type $resource_namespace/$resource_name using $kubeconfig"
    ready=$(kubectl --kubeconfig $kubeconfig -n $resource_namespace get $resource_type $resource_name -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' || echo)
    timeout=$(( $timeout - 5 ))
    if [[ "$ready" != "True" && $timeout -gt 0 ]]; then
      echo "status: $ready"
      sleep 5
    fi
  done

  if [[ "$ready" != "True" ]]; then
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
  while [[ "$ready" -lt "$min_ready" && $timeout -gt 0 ]]
  do
    echo "$timeout: checking readiness of $resource_type $resource_namespace/$resource_name using $kubeconfig"
    ready=$(kubectl --kubeconfig $kubeconfig -n $resource_namespace get $resource_type $resource_name -o jsonpath='{.status.readyReplicas}' || echo)
    timeout=$(( $timeout - 5 ))
    if [[ "$ready" -lt "$min_ready" && $timeout -gt 0 ]]; then
      echo "status: $ready (want $min_ready)"
      sleep 5
    fi
  done

  if [[ "$ready" -lt "$min_ready" ]]; then
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

  local file=$(tempfile)
  kubectl --kubeconfig "$kubeconfig" -n "$namespace" get secret "${cluster}-kubeconfig" -o jsonpath='{.data.value}' | base64 -d > "$file"
  echo "$file"
}
