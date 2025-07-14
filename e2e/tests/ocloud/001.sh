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
## TEST-NAME: Deploy edge cluster via Focom and O2IMS Operators
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

# shellcheck source=e2e/lib/_assertions.sh
source "${LIBDIR}/_assertions.sh"


# Clone the o2ims pkg
pkg_rev=$(porchctl rpkg clone -n default "https://github.com/nephio-project/catalog.git/nephio/optional/o2ims@$BRANCH" --repository mgmt o2ims | cut -f 1 -d ' ')
k8s_wait_exists "packagerev" "$pkg_rev"

# Create Draft
kubectl wait --for jsonpath='{.spec.lifecycle}'=Draft packagerevisions "$pkg_rev" --timeout="600s"
assert_branch_exists "drafts/o2ims/v1"
assert_commit_msg_in_branch "Rendering package" "drafts/o2ims/v1"

# Propose
info "proposing package $pkg_rev"
porchctl rpkg propose -n default "$pkg_rev"
kubectl wait --for jsonpath='{.spec.lifecycle}'=Proposed packagerevisions "$pkg_rev" --timeout="600s"
info "package $pkg_rev proposed"
assert_branch_exists "proposed/o2ims/v1"
assert_commit_msg_in_branch "Rendering package" "proposed/o2ims/v1"

# Approve
info "approving package $pkg_rev"
porchctl rpkg approve -n default "$pkg_rev"
info "package $pkg_rev approved"
kubectl wait --for jsonpath='{.spec.lifecycle}'=Published packagerevisions "$pkg_rev" --timeout="600s"
info "package $pkg_rev published"

kpt_wait_pkg "mgmt" "o2ims"

# Make sure the o2ims operator starts
k8s_wait_exists "deployment" "o2ims-operator" "" "o2ims"
kubectl rollout status deployment/o2ims-operator --namespace="o2ims" --timeout="600s"

# Create the simulated SMO cluster
focom_kubecofig="/tmp/focom-kubeconfig"
kind create cluster -n focom-cluster --kubeconfig $focom_kubecofig

# Get the focom operator pkg
tmp_pkg_path="/tmp/focom"
kpt pkg get --for-deployment https://github.com/nephio-project/catalog.git/nephio/optional/focom-operator@$BRANCH $tmp_pkg_path
# Apply it to the SMO cluster
kubectl --kubeconfig $focom_kubecofig apply -f $tmp_pkg_path

# Wait for the focom op to become available
k8s_wait_exists "deployment" "focom-operator-controller-manager" $focom_kubecofig "focom-operator-system"
kubectl rollout status deployment/focom-operator-controller-manager --namespace="focom-operator-system" --kubeconfig=$focom_kubecofig --timeout="600s"

# Update the kubeconfig IPAddress
ip=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' kind-control-plane)
sed "s|https://127.0.0.1:[^ ]*|https://$ip:6443|" ~/.kube/config > /tmp/kubeconfig-bak

#Create a secret to use towards the SMO cluster
kubectl create secret generic ocloud-kubeconfig --from-file=kubeconfig=/tmp/kubeconfig-bak --kubeconfig $focom_kubecofig

# Apply the sample focom provisioning request
k8s_apply "$TESTDIR/001-focom-provisioning-request.yaml" $focom_kubecofig

# wait for the edge cluster exists
k8s_wait_exists "workloadcluster" "edge"

# Wait for edge cluster to be ready
capi_cluster_ready "edge"

