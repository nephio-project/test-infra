#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2023 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
digest_raw=$(crane digest "$1")
echo "Signing \"$1@${digest_raw}\" image"
cosign sign -y --key env://COSIGN_PRIVATE_KEY "$1@${digest_raw}"
