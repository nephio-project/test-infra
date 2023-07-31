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

export HOME=${HOME:-/home/ubuntu/}
export E2EDIR=${E2EDIR:-$HOME/test-infra/e2e}
export TESTDIR=${TESTDIR:-$E2EDIR/tests}

source "$E2EDIR/lib/testing.sh"

let failed=0
test_summary=""
for t in $TESTDIR/*.sh; do
    if ! testing_run_test "$t"; then
      failed+=1
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
