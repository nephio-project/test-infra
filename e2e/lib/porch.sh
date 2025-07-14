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

# porch_wait_published_packagerev() - Waits for a kpt package revision to be published
function porch_wait_published_packagerev {
    local pkg_name="$1"
    local repository="$2"
    local revision="${3:-1}"
    local timeout=${4:-900}
    lapse=$timeout
    in_propose=0

    info "looking for published package revision $pkg_name on $repository"
    local found=""
    while [[ $lapse -gt 0 ]]; do
        for pkg_rev in $(kubectl get packagerevisions -o jsonpath="{range .items[?(@.spec.packageName==\"$pkg_name\")]}{.metadata.name}{\"\\n\"}{end}"); do
            if [ "$(kubectl get packagerevision "$pkg_rev" -o jsonpath='{.spec.repository}/{.spec.revision}')" == "$repository/$revision" ]; then
                found=$pkg_rev
                break
            fi
            # Force the package revision back to Draft if the PR stays proposed for more than 60 seconds
            if [ "$(kubectl get packagerevision "$pkg_rev" -o jsonpath='{.spec.lifecycle}')" == "Proposed" ]; then
                if [ $in_propose -ge 60 ]; then
                    info "rejecting package $pkg_name back to draft because it has been proposed for 60 seconds"
                    in_propose=0
                    porchctl rpkg reject -n default "$pkg_rev"
                else
                    info "waiting for package $pkg_name to be auto approved"
                    in_propose=$((in_propose + 5))
                fi
            fi
        done
        if [[ $found ]]; then
            info "found package published revision on $pkg_name"
            [ $((timeout * 2 / 3)) -lt $lapse ] || warn "$pkg_name package took $lapse seconds to be published"
            break
        fi
        lapse=$((lapse - 5))
        sleep 5
    done

    if [[ -z $found ]]; then
        kubectl get packagerevisions -o jsonpath="{range .items[?(@.spec.packageName==\"$pkg_name\")]}{.metadata.name}{\"\\n\"}{end}"
        error "Timed out waiting for revisions on $pkg_name package"
    fi
    kubectl wait --for jsonpath='{.spec.lifecycle}'=Published packagerevisions $found --timeout=10m
}

# porch_wait_packagerev_ready() - Waits for a kpt package revision's kpt pipeline to complete successfully
function porch_wait_packagerev_ready {
    local pkgrev_id="$1"
    local timeout=${2:-900}
    lapse=$timeout

    info "checking for condition-based readiness on \"$pkgrev_id\""
    local found=""
    while [[ $lapse -gt 0 ]]; do
        if ! kubectl get packagerevision "$pkgrev_id" -o jsonpath='{range .status.conditions[*]}{.type}{":"}{.status}{"\n"}{end}' | grep -E ":False$"; then
            info "found all conditions with status == \"True\" on $pkgrev_id"
            [[ $((timeout * 2 / 3)) -lt $lapse ]] || warn "$pkgrev_id package took $lapse seconds for pipeline to pass"
            break
        fi
        lapse=$((lapse - 5))
        sleep 5
    done
}