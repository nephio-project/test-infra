#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2023 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o errexit
set -o nounset
set -o pipefail

# debug() - This function prints a debug message in the standard output
function debug {
    [[ ${DEBUG:-false} != "true" ]] || _print_msg "DEBUG" "$1"
}

# info() - This function prints an information message in the standard output
function info {
    _print_msg "INFO" "$1"
}

# warn() - This function prints a warning message in the standard output
function warn {
    _print_msg "WARN" "$1"
}

# error() - This function prints an error message in the standard output
function error {
    _print_msg "ERROR" "$1"
    exit 1
}

function _print_msg {
    echo "$(date +%H:%M:%S) - $1: $2"
}

# get_pod_logs() - Collect logs from pods of a deployment
# Usage: get_pod_logs <deployment> <namespace> [kubeconfig]
function get_pod_logs {
    local deployment=$1
    local namespace=$2
    local kubeconfig=${3:-}
    local kubectl_cmd="kubectl"
    [[ -z "$kubeconfig" ]] || kubectl_cmd="kubectl --kubeconfig $kubeconfig"
    
    info "Collecting logs from deployment $deployment in $namespace namespace"
    local selector=$($kubectl_cmd get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.selector.matchLabels}' | jq -r 'to_entries|map("\(.key)=\(.value)")|join(",")')
    for pod in $($kubectl_cmd get pods -n "$namespace" -l "$selector" -o jsonpath='{.items[*].metadata.name}'); do
        info "Logs from pod: $pod"
        $kubectl_cmd logs -n "$namespace" "$pod" --all-containers=true --tail=100 || warn "Failed to get logs from $pod"
    done
}
