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

export E2EDIR=${E2EDIR:-$HOME/test-infra/e2e}

# shellcheck source=e2e/defaults.env
source "$E2EDIR/defaults.env"

# shellcheck source=e2e/lib/testing.sh
source "$LIBDIR/testing.sh"

failed=$((0))
test_summary=""
for t in $TESTDIR/*.sh; do
    if ! run_test "$t"; then
        failed=$((failed + 1))
        [[ ${FAIL_FAST:-false} != "true" ]] || break
    fi
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
