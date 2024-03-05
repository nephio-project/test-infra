#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2023 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o pipefail
set -o errexit
set -o nounset
[[ ${DEBUG:-false} != "true" ]] || set -o xtrace

start_at_test=""
finish_before_test=""

while getopts s:f: flag
do
    case "${flag}" in
        s) start_at_test=${OPTARG};;
        f) finish_before_test=${OPTARG};;
        *) ;;
    esac
done

export E2EDIR=${E2EDIR:-$HOME/test-infra/e2e}

# shellcheck source=e2e/defaults.env
source "$E2EDIR/defaults.env"

# shellcheck source=e2e/lib/testing.sh
source "$LIBDIR/testing.sh"

failed=$((0))
test_summary=""
sudo dmesg >/tmp/e2e_dmesg_base.log
for t in "$TESTDIR"/*.sh; do
    if [ -n "$start_at_test" ]
    then
        if [ "$t" == "$start_at_test" ]
        then
            start_at_test=""
        else
            continue
        fi
    fi

    if [ -n "$finish_before_test" ]
    then
        if [ "$t" == "$finish_before_test" ]
        then
            break
        fi
    fi

    if ! run_test "$t"; then
        failed=$((failed + 1))
        [[ ${FAIL_FAST:-false} != "true" ]] || break
    fi
    sudo dmesg >/tmp/e2e_dmesg_base.log
done
echo "TEST SUMMARY"
echo "------------"
echo -e "$test_summary"
echo "------------"
echo
if [[ $failed -gt 0 ]]; then
    echo "FAILED $failed tests"
    exit 1
fi
if [ "$(docker container inspect -f '{{.State.Running}}' docker_registry_proxy)" = "true" ]; then
    echo "Docker registry cache hits: $(docker logs docker_registry_proxy | grep '"upstream_cache_status":"HIT"' | wc -l)"
fi
