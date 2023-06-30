#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2023 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

for go_main in $(egrep -rl --null --include \*.go 'package\s+main\b' | xargs -0 -L 1 dirname); do
    pushd "$go_main" >/dev/null
    rm -f /tmp/cmd
    echo "Building $go_main file"
    go build -o "/tmp/cmd" >/dev/null 2>&1
    lichen -c /etc/lichen.yaml "/tmp/cmd" || exit 1
    popd >/dev/null
done
