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
## TEST-NAME: Deploy regional workload cluster
##

set -o pipefail
set -o errexit
set -o nounset
[[ ${DEBUG:-false} != "true" ]] || set -o xtrace

# shellcheck source=e2e/defaults.env
source "$E2EDIR/defaults.env"

# shellcheck source=e2e/lib/k8s.sh
source "${LIBDIR}/k8s.sh"

# shellcheck source=e2e/lib/capi.sh
source "${LIBDIR}/capi.sh"

# shellcheck source=e2e/lib/porch.sh
source "${LIBDIR}/porch.sh"

# shellcheck source=e2e/lib/_assertions.sh
source "${LIBDIR}/_assertions.sh"

# shellcheck source=e2e/lib/_utils.sh
source "${LIBDIR}/_utils.sh"

function _curl_workload_cluster_content {
    curl -s "http://$(kubectl get services -n gitea gitea -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):3000/nephio/mgmt/raw/branch/$1/regional/workload-cluster.yaml"
}

# Assertions

function assert_workload_resource_contains {
    assert_contains "$(_curl_workload_cluster_content "$1")" "$2" "$3"
}

regional_pkg_rev=$(kpt alpha rpkg clone -n default https://github.com/nephio-project/catalog.git/infra/capi/nephio-workload-cluster@main --repository mgmt regional | cut -f 1 -d ' ')
k8s_wait_exists "packagerev" "$regional_pkg_rev"

# Draft creation
porch_wait_log_entry "Creating packagerev default/mgmt-"
assert_lifecycle_equals "$regional_pkg_rev" "Draft"
assert_branch_exists "drafts/regional/v1"
assert_commit_msg_in_branch "Intermediate commit" "drafts/regional/v1"
assert_workload_resource_contains "drafts/regional/v1" "clusterName: regional" "Workload cluster has not been transformed properly"

pushd "$(mktemp -d -t "001-pkg-XXX")" >/dev/null
trap popd EXIT
kpt alpha rpkg pull -n default "$regional_pkg_rev" regional
kpt fn eval --image "gcr.io/kpt-fn/set-labels:v0.2.0" regional -- "nephio.org/site-type=regional" "nephio.org/region=us-west1"
assert_contains "$(cat regional/workload-cluster.yaml)" "nephio.org/region: us-west1" "Workload cluster doesn't have region label"

kpt alpha rpkg push -n default "$regional_pkg_rev" regional
porch_wait_log_entry "Update.*packagerevisionresources/${regional_pkg_rev},"

# Proposal
kpt alpha rpkg propose -n default "$regional_pkg_rev"
porch_wait_log_entry "Update.*packagerevisions/${regional_pkg_rev},"
assert_lifecycle_equals "$regional_pkg_rev" "Proposed"
assert_branch_exists "proposed/regional/v1"
assert_commit_msg_in_branch "Intermediate commit" "proposed/regional/v1"
assert_workload_resource_contains "proposed/regional/v1" "nephio.org/site-type: regional" "Workload cluster has not been transformed properly to proposed"

# Approval
kpt alpha rpkg approve -n default "$regional_pkg_rev"
porch_wait_log_entry "Update.*/${regional_pkg_rev}.*/approval"
assert_lifecycle_equals "$regional_pkg_rev" "Published"
assert_workload_resource_contains "main" "nephio.org/site-type: regional" "Workload cluster has not been successfully merged into main branch"

k8s_wait_exists "workloadcluster" "regional"
capi_cluster_ready "regional"
