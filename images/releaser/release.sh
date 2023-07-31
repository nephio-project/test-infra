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
digest=$(echo "${digest_raw//:/-}")
echo "Image digest: $digest_raw"
echo $digest_raw >$ARTIFACTS/trivy.log
trivy image "$1" >>$ARTIFACTS/trivy.log 2>&1
echo $digest_raw >$ARTIFACTS/grype.log
grype -v "$1" >>$ARTIFACTS/grype.log 2>&1
syft "$1" --output=spdx-json >>$ARTIFACTS/$digest.sbom
repo=$(echo "$1" | awk -F':' '{print $1}')
echo $repo

oras tag docker.io/"$1" $digest

oras push --artifact-type sbom/example docker.io/$repo:$digest.sbom $digest.sbom
