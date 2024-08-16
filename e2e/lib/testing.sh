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

# shellcheck source=e2e/lib/_utils.sh
source "${E2EDIR:-$HOME/test-infra/e2e}/lib/_utils.sh"

function _get_test_metadata {
    local testfile=$1
    local fieldname=$2

    local line=$(grep "$fieldname" "$testfile" || echo "")
    echo "$line" | cut -d : -f 2
}

# run_test() - Runs a functional test in the current sandbox
function run_test {
    local testfile=$1

    local testname=$(_get_test_metadata "$testfile" "TEST-NAME")
    int_start=$(date +%s)
    mgmt_nic="$(ip route get 1.1.1.1 | awk 'NR==1 { print $5 }')"
    ratio=$((1024 * 1024)) # MB
    if [ -f "/sys/class/net/$mgmt_nic/statistics/rx_bytes" ]; then
        int_rx_bytes_before=$(cat "/sys/class/net/$mgmt_nic/statistics/rx_bytes")
    fi
    info "+++++ starting $testfile $testname"
    local rc=0
    /bin/bash "$testfile" || rc=$?
    local result="PASS"
    if [[ $rc != 0 ]]; then
        result="FAIL ($rc)"
    fi

    info "+++++ finished $testfile $testname (result: $result)"
    local seconds="$(($(date +%s) - int_start))"
    printf "TIME $(basename $testfile): %s secs\n" $seconds
    if [ -f "/sys/class/net/$mgmt_nic/statistics/rx_bytes" ]; then
        int_rx_bytes_after=$(cat "/sys/class/net/$mgmt_nic/statistics/rx_bytes")
        printf "%'.f MB total downloaded\n" "$(((int_rx_bytes_after - int_rx_bytes_before) / ratio))"
    fi
    test_summary+="$(basename $testfile): $result in $seconds seconds\n"

    if [[ ${DEBUG:-false} == "true" ]]; then
        debug "Porch Controller logs"
        kubectl logs deployment/porch-controllers -n porch-system --since "$(($(date +%s) - int_start))s" | sed -e '/PackageVariant/!d;/resources changed/!d'
    fi

    return $rc
}
