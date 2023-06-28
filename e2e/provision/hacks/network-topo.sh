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
##
set -o pipefail
set -o errexit
set -o nounset

export LEAF_IP=$(docker inspect net-free5gc-net-leaf -f '{{.NetworkSettings.Networks.kind.IPAddress}}')

envsubst <"$TESTDIR/003-network-topo.tmpl" >"$TESTDIR/003-network-topo.yaml"
