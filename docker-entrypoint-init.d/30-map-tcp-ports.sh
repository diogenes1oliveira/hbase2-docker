#!/usr/bin/env bash

set -euo pipefail

# Initialization script that sets up port mappings from $HBASE_PORT_MAPPINGS

if [ -n "${HBASE_PORT_MAPPINGS:-}" ]; then
    if [ -z "${HBASE_BACKGROUND_PIDS_FILE:-}" ]; then
        echo >&2 "ERROR: no PIDs file"
        exit 1
    fi

    (
        eval set -- "$HBASE_PORT_MAPPINGS"
        tcp-map-ports --pids-file "$HBASE_BACKGROUND_PIDS_FILE" "$@"
    )
fi
