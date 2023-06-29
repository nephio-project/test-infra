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

export PARALLEL=${1:-false}

source "$E2EDIR/lib/testing.sh"

if [[ ${PARALLEL} == "false" ]]; then
    for t in $TESTDIR/*.sh; do
        testing_run_test "$t"
    done
    exit 0
fi

## Run in parallel as much as possible

for tg in $(ls -1 $TESTDIR/*.sh | sed -e "s?$TESTDIR/??" | cut -d '-' -f 1 | sort | uniq); do
    testing_run_group $TESTDIR $tg
done
