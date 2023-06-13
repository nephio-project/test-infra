#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2023 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# This file contains conveniences for the user on the test machine. It will be
# copied to the .bash_aliases file for that user.

alias k=kubectl

function get_capi_kubeconfig {
    local cluster=$1

    if [[ -z $cluster ]]; then
        echo "Usage: $0 cluster-name"
        return 1
    fi

    kubectl get secret "${cluster}-kubeconfig" -o jsonpath='{.data.value}' | base64 -d >"${cluster}-kubeconfig"
}
