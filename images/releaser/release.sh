#!/usr/bin/env bash
digest_raw=$(crane digest "$1")
digest=$(echo $digest_raw| sed s/:/-/g)
echo "Image digest: $digest_raw"
echo $digest_raw > $ARTIFACTS/trivy.log
trivy image "$1" >> $ARTIFACTS/trivy.log 2>&1
echo $digest_raw > $ARTIFACTS/grype.log
grype -v "$1" >> $ARTIFACTS/grype.log 2>&1
syft "$1" --output=spdx-json >> $ARTIFACTS/$digest.sbom
repo=$(echo "$1" | awk -F':' '{print $1}')
echo $repo


oras tag docker.io/"$1" $digest

oras push --artifact-type sbom/example docker.io/$repo:$digest.sbom $digest.sbom
