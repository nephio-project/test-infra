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
## TEST-NAME: Deploy OAI-GNB and OAI-NR-UE
##

set -o pipefail
set -o errexit
set -o nounset
[[ ${DEBUG:-false} != "true" ]] || set -o xtrace

# shellcheck source=e2e/defaults.env
source "$E2EDIR/defaults.env"

# shellcheck source=e2e/lib/k8s.sh
source "${LIBDIR}/k8s.sh"

_core_kubeconfig="$(k8s_get_capi_kubeconfig "core")"
amf_ip=$(kubectl get nfdeployment -n oai-core --kubeconfig "$_core_kubeconfig" amf-core -o jsonpath='{.spec.interfaces[0].ipv4.address}')
amf_gateway=$(kubectl get nfdeployment -n oai-core --kubeconfig "$_core_kubeconfig" amf-core -o jsonpath='{.spec.interfaces[0].ipv4.gateway}')

if ! command -v nmap; then
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
    ubuntu | debian)
        sudo apt update
        sudo -H -E apt-get -y install --no-install-recommends nmap
        ;;
    esac
fi

ip_address=$(nmap -sL -n "$amf_ip" | awk 'NR==10{print $NF}')

pushd "$(mktemp -d -t "004-pkg-XXX")" >/dev/null
trap popd EXIT
kpt pkg get https://github.com/OPENAIRINTERFACE/oai-packages.git/oai-gnb@main oai-gnb
kpt fn eval oai-gnb -i search-replace:v0.2.0 -- 'by-value=172.2.1.253/24' "put-value=$ip_address"
kpt fn eval oai-gnb -i search-replace:v0.2.0 -- 'by-value=172.2.1.254' "put-value=$ip_address"
kpt fn eval oai-gnb -i search-replace:v0.2.0 -- 'by-value=172.2.1.1' "put-value=$amf_gateway"
kpt fn render oai-gnb
kpt live init oai-gnb --kubeconfig "$_core_kubeconfig"
kpt live apply oai-gnb --kubeconfig "$_core_kubeconfig"

k8s_wait_ready_replicas "deployment" "oaignb" "$_core_kubeconfig" "oai5g-ran"
