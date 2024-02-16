#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2023 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o errexit
set -o nounset
set -o pipefail
DEBUG="${DEBUG:-false}"
if [[ ${DEBUG} == "true" ]]; then
    set -o xtrace
fi

# shellcheck source=e2e/lib/kpt.sh
source "${E2EDIR:-$HOME/test-infra/e2e}/lib/kpt.sh"

# assert_are_equal() - This assertion checks if the inputs are equal
function assert_are_equal {
    local input=$1
    local expected=$2
    local error_msg=${3:-"got $input, want $expected"}

    if [[ $DEBUG == "true" ]]; then
        debug "Are equal Assertion - value: $1 expected: $2"
    fi
    if [ "$input" != "$expected" ]; then
        error "$error_msg"
    fi
}

# assert_contains() - This assertion checks if the input contains another value
function assert_contains {
    local input=$1
    local expected=$2
    local error_msg=${3:-"$input doesn't contains $expected"}

    if [[ $DEBUG == "true" ]]; then
        debug "Contains Assertion - value: $1 expected: $2"
    fi
    if [[ $input != *"$expected"* ]]; then
        error "$error_msg"
    fi
}

function _assert_repo_exists {
    local repo_expected=$1
    local error_msg=${2:-"There is no $repo_expected repository"}

    if [[ $DEBUG == "true" ]]; then
        debug "Repository exists Assertion - value: $1"
    fi
    assert_contains "$(curl_gitea_api "repos/$repo_expected" 'import json; import sys; print(json.loads(sys.stdin.read())["full_name"])')" "$repo_expected" "$error_msg"
}

# assert_branch_exists() - This assertion checks if the branch exists in a given repo
function assert_branch_exists {
    local branch_expected=$1
    local repo=${2:-nephio/mgmt}
    local error_msg=${3:-"There is no $branch_expected branch in $repo repository"}

    _assert_repo_exists "$repo"

    if [[ $DEBUG == "true" ]]; then
        debug "Branch exists Assertion - value: $1"
    fi
    assert_contains "$(curl_gitea_api "repos/$repo/branches" 'import json; import sys; print("\n".join([branch["name"] for branch in json.loads(sys.stdin.read())]))')" "$branch_expected" "$error_msg"
}

# assert_commit_msg_in_branch() - This assertion checks if the commit message exists in a given branch for a repo
function assert_commit_msg_in_branch {
    local commit_msg_expected=$1
    local branch=${2}
    local repo=${3:-nephio/mgmt}
    local error_msg="There is no commits with $commit_msg_expected as message in the $branch branch"

    _assert_repo_exists "$repo"
    assert_branch_exists "$branch" "$repo"

    if [[ $DEBUG == "true" ]]; then
        debug "Commit message contains Assertion - value: $1"
    fi
    assert_contains "$(curl_gitea_api "repos/$repo/branches/$branch" 'import json; import sys; print(json.loads(sys.stdin.read())["commit"]["message"])')" "$commit_msg_expected" "$error_msg"
}

# assert_lifecycle_equals() - This assertion checks if the lifecycle of a given package reviews is the expected
function assert_lifecycle_equals {
    local package_revision=$1
    local lifecycle_expected=$2

    if [[ $DEBUG == "true" ]]; then
        debug "Lifecycle package Assertion - package revision: $1 lifecycle expected: $2"
    fi
    assert_are_equal "$(kubectl get packagerevisions "$package_revision" -o jsonpath='{.spec.lifecycle}')" "$lifecycle_expected" "The lifecycle for regional package is not $lifecycle_expected"
}
