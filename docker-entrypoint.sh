#!/usr/bin/env bash

set -euo pipefail

if [ -d /docker-entrypoint-init.d ]; then
    echo >&2 "INFO: finding initialization scripts"

    while read -r script; do
        echo >&2 "INFO: executing initialization script $script"
        # shellcheck disable=SC1090
        source "$script"
    done < <(find /docker-entrypoint-init.d -mindepth 1 -maxdepth 1 -name '*.sh' | sort )

    echo >&2 "INFO: executed all initialization scripts"
fi

exec "$@"
