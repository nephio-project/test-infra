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
## TEST-NAME: Deploy free5gc-cp to regional workload cluster
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

# shellcheck source=e2e/lib/porch.sh
source "${LIBDIR}/porch.sh"

# shellcheck source=e2e/lib/_assertions.sh
source "${LIBDIR}/_assertions.sh"

pkg_rev=$(porchctl rpkg clone -n default "https://github.com/nephio-project/catalog.git/workloads/free5gc/free5gc-cp@$REVISION" --repository regional free5gc-cp | cut -f 1 -d ' ')
k8s_wait_exists "packagerev" "$pkg_rev"

porch_wait_log_entry "Creating packagerev default/regional-"
assert_lifecycle_equals "$pkg_rev" "Draft"
assert_branch_exists "drafts/free5gc-cp/v1" "nephio/regional"
assert_commit_msg_in_branch "Intermediate commit" "drafts/free5gc-cp/v1" "nephio/regional"

porchctl rpkg propose -n default "$pkg_rev"
porch_wait_log_entry "Update.*packagerevisions/${pkg_rev},"
assert_lifecycle_equals "$pkg_rev" "Proposed"
assert_branch_exists "proposed/free5gc-cp/v1" "nephio/regional"
assert_commit_msg_in_branch "Intermediate commit" "proposed/free5gc-cp/v1" "nephio/regional"

porchctl rpkg approve -n default "$pkg_rev"
porch_wait_log_entry "Update.*/${pkg_rev}.*/approval"
assert_lifecycle_equals "$pkg_rev" "Published"

kpt_wait_pkg "regional" "free5gc-cp"
k8s_wait_ready_replicas "statefulset" "mongodb" "$(k8s_get_capi_kubeconfig "regional")" "free5gc-cp"
