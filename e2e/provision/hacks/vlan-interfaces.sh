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

# shellcheck source=e2e/defaults.env
source "$E2EDIR/defaults.env"

kubeconfig="$HOME/.kube/config"

for worker in $(kubectl get machines -l cluster.x-k8s.io/control-plane!= -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --kubeconfig "$kubeconfig"); do
    for i in {2..6}; do
        docker exec "$worker" ip link add link eth1 name "eth1.$i" type vlan id "$i"
        docker exec "$worker" ip link set up "eth1.$i"
    done
done
