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
    /bin/bash "$testfile"
    echo "+++++ $(date): finished $testfile $testname"
    printf "%s secs\n" "$(($(date +%s) - int_start))"

    echo "Porch Controller logs"
    kubectl logs deployment/porch-controllers -n porch-system --since "$(($(date +%s) - int_start))s" | sed -e '/PackageVariant/!d;/resources changed/!d'
}
