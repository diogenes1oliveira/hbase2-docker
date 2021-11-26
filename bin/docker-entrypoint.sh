#!/usr/bin/env bash

set -euo pipefail

source hbase-config-build.sh xml

if [ "$#" -eq 0 ] || [ "${1#-}" != "${1}" ]; then
    # no args or first arg is a flag
    exec hbase-run-foreground.sh "$@"
else
    exec "$@"
fi
