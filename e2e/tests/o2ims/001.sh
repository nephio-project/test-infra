#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2025 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

## TEST METADATA
## TEST-NAME: Deploy edge cluster via O2IMS Operator
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

# If the packagerevisions endpoint is down, restart the porch-system pod until the endpoint is up
exit_code=0
kubectl get packagerevisions || exit_code=$?
while [ $exit_code -ne 0 ]; do
    exit_code=0
    pod="$(kubectl get pods -n porch-system --no-headers -o custom-columns=":metadata.name" | grep server)"
    kubectl delete pod $pod -n porch-system
    kubectl wait --for=delete pod $pod -n porch-system --timeout=600s
    pod="$(kubectl get pods -n porch-system --no-headers -o custom-columns=":metadata.name" | grep server)"
    k8s_wait_ready "pod" $pod "" "porch-system"
    kubectl get packagerevisions || exit_code=$?
done

# Clone the catalog
pkg_rev=$(porchctl rpkg clone -n default "https://github.com/nephio-project/catalog.git/nephio/optional/o2ims@$BRANCH" --repository mgmt o2ims | cut -f 1 -d ' ')
k8s_wait_exists "packagerev" "$pkg_rev"

# Draft
kubectl wait --for jsonpath='{.spec.lifecycle}'=Draft packagerevisions "$pkg_rev" --timeout="600s"
assert_branch_exists "drafts/o2ims/v1"
assert_commit_msg_in_branch "Intermediate commit" "drafts/o2ims/v1"

# Proposal
porchctl rpkg propose -n default "$pkg_rev"
kubectl wait --for jsonpath='{.spec.lifecycle}'=Proposed packagerevisions "$pkg_rev" --timeout="600s"
assert_branch_exists "proposed/o2ims/v1"
assert_commit_msg_in_branch "Intermediate commit" "proposed/o2ims/v1"

# Approval
info "approving package $pkg_rev"
porchctl rpkg approve -n default "$pkg_rev"
info "approved package $pkg_rev"
kubectl wait --for jsonpath='{.spec.lifecycle}'=Published packagerevisions "$pkg_rev" --timeout="600s"
info "published package $pkg_rev"

kpt_wait_pkg "mgmt" "o2ims"

# Wait for the o2ims pod to appear
exit_code=0
o2ims_pod="$(kubectl get pods -n o2ims --no-headers -o custom-columns=":metadata.name" | grep o2ims)" || exit_code=$?
while [ $exit_code -ne 0 ]; do
    exit_code=0
    o2ims_pod="$(kubectl get pods -n o2ims --no-headers -o custom-columns=":metadata.name" | grep o2ims)" || exit_code=$?
    sleep 1
done

# Make sure the operator starts
o2ims_pod="$(kubectl get pods -n o2ims --no-headers -o custom-columns=":metadata.name" | grep o2ims)"
k8s_wait_ready "pod" $o2ims_pod "" "o2ims"

# Apply the sample provisioning request
k8s_apply "$TESTDIR/001-sample-provisioning-request.yaml"

# wait for the edge cluster
k8s_wait_exists "workloadcluster" "edge"

# Wait for the kind edge cluster
exit_code=0
kind get clusters | grep edge || exit_code=$?
while [ $exit_code -ne 0 ]; do
    exit_code=0
    sleep 5
    kind get clusters | grep edge || exit_code=$?
done
