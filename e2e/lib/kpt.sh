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

# shellcheck source=e2e/lib/_utils.sh
source "${E2EDIR:-$HOME/test-infra/e2e}/lib/_utils.sh"

# curl_gitea_api() - This function queries the Gitea API and executes a python script on the result
function curl_gitea_api {
    local api=$1
    local python_script=$2
    local url="http://$(kubectl get services -n gitea gitea -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):3000/api/v1/$api"

    curl -s "$url" | python3 -c "$python_script"
}

function _wait_for_user_repo {
    local repo=$1
    local user=${2:-nephio}
    local timeout=${3:-600}

    info "looking for $repo repository of $user user"
    local found="False"
    while [[ $timeout -gt 0 ]]; do
        found=$(curl_gitea_api "repos/$user/$repo" 'import json; import sys; print("full_name" in json.loads(sys.stdin.read()))')
        if [[ $found == "True" ]]; then
            debug "timeout: $timeout"
            break
        fi
        timeout=$((timeout - 5))
        sleep 5
    done

    if [[ $found != "True" ]]; then
        curl_gitea_api "users/$user/repos" 'import json; import sys; print("\n".join(repo["full_name"] for repo in json.loads(sys.stdin.read())))'
        error "Timed out waiting for $repo repository"
    else
        info "Found $user/$repo repository"
    fi
}

# kpt_wait_pkg() - Wait for a given kpt package to exist in a given repository
function kpt_wait_pkg {
    local repo=$1
    local pkg=$2
    local user=${3:-nephio}
    local timeout=${4:-600}

    _wait_for_user_repo "$repo" "$user"
    info "looking for $pkg kpt package on $user/$repo repository"
    local found="False"
    while [[ $timeout -gt 0 ]]; do
        found=$(curl_gitea_api "repos/$user/$repo/contents" "import json; import sys; print('$pkg' in [dir['path'] for dir in json.loads(sys.stdin.read()) if dir['type'] == 'dir' ])")
        if [[ $found == "True" ]]; then
            debug "timeout: $timeout"
            break
        fi
        timeout=$((timeout - 5))
        sleep 5
    done

    if [[ $found != "True" ]]; then
        curl_gitea_api "repos/$user/$repo/contents" 'import json; import sys; print("\n".join(dir["path"] for dir in json.loads(sys.stdin.read()) if dir["type"] == "dir" ))'
        error "Timed out waiting for $pkg kpt package"
    else
        info "Found $user/$repo repository"
    fi

}
