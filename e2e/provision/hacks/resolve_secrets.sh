#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2023 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o pipefail
set -o errexit
set -o nounset

function destroy_kpt_pkg {
    local temp_dir=$1
    local name=$2

    echo "destroying $name kpt package in $temp_dir . . ."
    pushd "$temp_dir" >/dev/null
    kpt live --kubeconfig "$HOME/.kube/config" destroy "$temp_dir/$name"
    popd >/dev/null
    echo "destroyed $name kpt package in $temp_dir"
}

function apply_kpt_pkg {
    local temp_dir=$1
    local name=$2

    echo "applying $name kpt package in $temp_dir . . ."
    pushd "$temp_dir" >/dev/null
    kpt live --kubeconfig "$HOME/.kube/config" apply "$temp_dir/$name" --reconcile-timeout 10m
    popd >/dev/null
    echo "applied $name kpt package in $temp_dir"
}

kpt_package_count=$(find /tmp -mindepth 1 -maxdepth 1 -type d -name 'kpt*' | wc -l)

if ((kpt_package_count != 3)); then
    echo "there must be three and only three kpt temporary directories in /tmp"
    exit 1
fi

mgmt_temp_dir=$(find /tmp/kpt* | grep 'mgmt\/token-configsync.yaml$' | sed 's/\/mgmt\/token-configsync.yaml$//')
mgmt_rootsync_temp_dir=$(find /tmp/kpt* | grep 'rootsync.yaml$' | sed 's/\/mgmt\/rootsync.yaml$//')
mgmt_staging_temp_dir=$(find /tmp/kpt* | grep 'mgmt-staging$' | sed 's/\/mgmt-staging$//')

echo "found mgmt kpt package in $mgmt_temp_dir"
echo "found mgmt rootsync kpt package in $mgmt_rootsync_temp_dir"
echo "found mgmt-staging kpt package in $mgmt_staging_temp_dir"

destroy_kpt_pkg "$mgmt_staging_temp_dir" "mgmt-staging"
destroy_kpt_pkg "$mgmt_rootsync_temp_dir" "mgmt"
destroy_kpt_pkg "$mgmt_temp_dir" "mgmt"

echo "waiting 60 seconds for package deletions to propogate . . ."
sleep 60
echo "continuing . . ."

apply_kpt_pkg "$mgmt_temp_dir" "mgmt"
apply_kpt_pkg "$mgmt_rootsync_temp_dir" "mgmt"
apply_kpt_pkg "$mgmt_staging_temp_dir" "mgmt-staging"
