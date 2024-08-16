#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2023 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

REPORTS_DIR=$(pwd)/reports/

mkdir -p $REPORTS_DIR/

for go_main in $(egrep -rl --null --include \*.go 'package\s+main\b' | xargs -0 -L 1 dirname); do
    pushd "$go_main" >/dev/null
    gocov test ./... | gocov-html >$REPORTS_DIR/${go_main//\//_}.html
    popd >/dev/null
done
