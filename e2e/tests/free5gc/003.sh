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

kubectl wait --for jsonpath='{.spec.lifecycle}'=Draft packagerevisions "$pkg_rev" --timeout="600s"
assert_branch_exists "drafts/free5gc-cp/v1" "nephio/regional"
assert_commit_msg_in_branch "Intermediate commit" "drafts/free5gc-cp/v1" "nephio/regional"

porchctl rpkg propose -n default "$pkg_rev"
kubectl wait --for jsonpath='{.spec.lifecycle}'=Proposed packagerevisions "$pkg_rev" --timeout="600s"
assert_branch_exists "proposed/free5gc-cp/v1" "nephio/regional"
assert_commit_msg_in_branch "Intermediate commit" "proposed/free5gc-cp/v1" "nephio/regional"

porchctl rpkg approve -n default "$pkg_rev"
kubectl wait --for jsonpath='{.spec.lifecycle}'=Published packagerevisions "$pkg_rev" --timeout="600s"

kpt_wait_pkg "regional" "free5gc-cp"
k8s_wait_ready_replicas "statefulset" "mongodb" "$(k8s_get_capi_kubeconfig "regional")" "free5gc-cp"
