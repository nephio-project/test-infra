#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2024 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <image_registry> <image_repo> <image_name> <image_tag>"
    exit 1
fi
IMAGE_REGISTRY=$1
IMAGE_REPO=$2
IMAGE_NAME=$3
IMAGE_TAG=$4
SLEEP_INTERVAL=60
MAX_RETRIES=20
export DOCKER_CONFIG=/root/.docker/

check_image() {
	if OUT=$(crane digest $IMAGE_REGISTRY/$IMAGE_REPO/$IMAGE_NAME:$IMAGE_TAG); then
        echo "$OUT"
    else
        echo "not_available"
    fi
}

retry_count=0

while true; do
    echo "Checking for Docker image: $IMAGE_NAME:$IMAGE_TAG"

    result=$(check_image)
    if [[ "$result" =~ ^sha256.* ]]; then
        echo "Image $IMAGE_NAME:$IMAGE_TAG is available on Docker Hub. Signing"
        cosign sign -y --key env://COSIGN_PRIVATE_KEY "$1/$2/$3:$4@${result}"
        exit 0
    else
        echo "Image $IMAGE_NAME:$IMAGE_TAG is not available on Docker Hub."
        ((retry_count++))
        echo "Attempt $retry_count of $MAX_RETRIES."

        if [ $retry_count -ge $MAX_RETRIES ]; then
            echo "Maximum number of retries ($MAX_RETRIES) reached. Exiting."
            exit 1
        fi
    fi

    echo "Waiting for $SLEEP_INTERVAL seconds before next check..."
    sleep $SLEEP_INTERVAL
done

