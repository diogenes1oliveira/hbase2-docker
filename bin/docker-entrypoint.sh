#!/usr/bin/env bash

set -euo pipefail

if [ -d /docker-entrypoint-init.d ]; then
    while read -r script; do
        source "${script}"
    done < <(find /docker-entrypoint-init.d -mindepth 1 -maxdepth 1 -name '*.sh' | sort )
fi

source /bin/hbase-config-build.sh xml

if [ "$#" -eq 0 ] || [ "${1#-}" != "${1}" ]; then
    # no args or first arg is a flag
    exec /bin/hbase-run-foreground.sh "$@"
else
    exec "$@"
fi
