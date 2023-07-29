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

function testing_get_test_metadata {
    local testfile=$1
    local fieldname=$2

    local line=$(grep "$fieldname" "$testfile" || echo "")
    echo "$line" | cut -d : -f 2
}

function testing_run_test {
    local testfile=$1

    local testname=$(testing_get_test_metadata "$testfile" "TEST-NAME")
    int_start=$(date +%s)
    echo "+++++ $(date): starting $testfile $testname"
    local rc=0
    /bin/bash "$testfile" || rc=$?
    local result="PASS"
    if [[ $rc != 0 ]]; then
        result="FAIL ($rc)"
    fi

    echo "+++++ $(date): finished $testfile $testname (result: $result)"
    local seconds="$(($(date +%s) - int_start))"
    printf "TIME $(basename $testfile): %s secs\n" $seconds
    test_summary="${test_summary-}$(echo && echo $(basename $testfile): $result in $seconds seconds)"

    if [[ ${DEBUG:-false} == "true" ]]; then
        echo "Porch Controller logs"
        kubectl logs deployment/porch-controllers -n porch-system --since "$(($(date +%s) - int_start))s" | sed -e '/PackageVariant/!d;/resources changed/!d'
    fi
}
