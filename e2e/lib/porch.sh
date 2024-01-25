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

# porch_wait_log_entry() - Waits for the entry log in Porch server
function porch_wait_log_entry {
    local pattern="$1"
    local timeout=${2:-600}

    info "looking for $pattern log entry in porch server($(kubectl get pods -n porch-system -l app=porch-server -o jsonpath='{.items[*].metadata.name}'))"
    local found=""
    while [[ $timeout -gt 0 ]]; do
        found=$(kubectl logs -n porch-system "$(kubectl get pods -n porch-system -l app=porch-server -o jsonpath='{.items[*].metadata.name}')" | { grep "$pattern" || :; })
        if [[ $found ]]; then
            debug "timeout: $timeout"
            break
        fi
        timeout=$((timeout - 5))
        sleep 5
    done

    if [[ -z $found ]]; then
        kubectl logs -n porch-system "$(kubectl get pods -n porch-system -l app=porch-server -o jsonpath='{.items[*].metadata.name}')"
        error "Timed out waiting for $pattern"
    fi
    info "Found $pattern log entry in porch server"
}

# porch_wait_published_packagerev() - Waits for a kpt package revision gets published
function porch_wait_published_packagerev {
    local pkg_name="$1"
    local repository="$2"
    local revision="${3:-main}"
    local timeout=${4:-900}

    info "looking for package published revision on $pkg_name"
    local found=""
    while [[ $timeout -gt 0 ]]; do
        for pkg_rev in $(kubectl get packagerevisions -o jsonpath="{range .items[?(@.spec.packageName==\"$pkg_name\")]}{.metadata.name}{\"\\n\"}{end}"); do
            if [ "$(kubectl get packagerevision "$pkg_rev" -o jsonpath='{.spec.repository}/{.spec.revision}')" == "$repository/$revision" ]; then
                found=$pkg_rev
                break
            fi
        done
        if [[ $found ]]; then
            debug "timeout: $timeout"
            break
        fi
        timeout=$((timeout - 5))
        sleep 5
    done

    if [[ -z $found ]]; then
        kubectl get packagerevisions -o jsonpath="{range .items[?(@.spec.packageName==\"$pkg_name\")]}{.metadata.name}{\"\\n\\\"}{end}"
        error "Timed out waiting for revisions on $pkg_name package"
    fi
    kubectl wait --for jsonpath='{.spec.lifecycle}'=Published packagerevisions $found --timeout=10m
}
