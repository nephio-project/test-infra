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
## TEST-NAME: Define IP Address pools on OAI clusters
##

set -o pipefail
set -o errexit
set -o nounset
[[ ${DEBUG:-false} != "true" ]] || set -o xtrace

# shellcheck source=e2e/defaults.env
source "$E2EDIR/defaults.env"

# shellcheck source=e2e/lib/k8s.sh
source "${LIBDIR}/k8s.sh"

# shellcheck source=e2e/lib/kpt.sh
source "${LIBDIR}/kpt.sh"

# shellcheck source=e2e/lib/capi.sh
source "${LIBDIR}/capi.sh"

# shellcheck source=e2e/lib/porch.sh
source "${LIBDIR}/porch.sh"

# shellcheck source=e2e/lib/_assertions.sh
source "${LIBDIR}/_assertions.sh"

function _define_ip_address_pool {
    local cluster=$1
    local cidr=$2

    pushd "$(mktemp -d -t "001-pkg-XXX")" >/dev/null
    trap popd RETURN

    pkg_rev=$(kpt alpha rpkg clone -n default https://github.com/nephio-project/catalog.git/distros/sandbox/metallb-sandbox-config@main --repository mgmt-staging "$cluster-metallb-sandbox-config" | cut -f 1 -d ' ')
    k8s_wait_exists "packagerev" "$pkg_rev"
    kpt alpha rpkg pull -n default "$pkg_rev" "$cluster-metallb-sandbox-config"
    kpt fn eval --image "gcr.io/kpt-fn/search-replace:v0.2" "$cluster-metallb-sandbox-config" -- 'by-path=spec.addresses[0]' "put-value=$cidr"
    kpt fn eval --image "gcr.io/kpt-fn/set-annotations:v0.1.4" "$cluster-metallb-sandbox-config" -- "nephio.org/cluster-name=$cluster"

    # Push changes
    kpt alpha rpkg push -n default "$pkg_rev" "$cluster-metallb-sandbox-config"
    porch_wait_log_entry "Update.*packagerevisionresources/${pkg_rev},"

    # Propose
    kpt alpha rpkg propose -n default "$pkg_rev"
    porch_wait_log_entry "Update.*packagerevisions/${pkg_rev},"
    assert_lifecycle_equals "$pkg_rev" "Proposed"
    assert_branch_exists "proposed/$cluster-metallb-sandbox-config/v1" "nephio/mgmt-staging"
    assert_commit_msg_in_branch "Intermediate commit" "proposed/$cluster-metallb-sandbox-config/v1" "nephio/mgmt-staging"

    # Approval
    kpt alpha rpkg approve -n default "$pkg_rev"
    porch_wait_log_entry "Update.*/${pkg_rev}.*/approval"
    assert_lifecycle_equals "$pkg_rev" "Published"
}

declare -A clusters
clusters=(
    ["core"]="172.18.16.0/20"
    ["regional"]="172.18.32.0/20"
    ["edge"]="172.18.48.0/20"
)

# Define MetalLB IP ranges
for cluster in "${!clusters[@]}"; do
    _define_ip_address_pool "$cluster" "${clusters[$cluster]}"
done
