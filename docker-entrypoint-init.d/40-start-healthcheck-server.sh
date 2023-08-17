#!/usr/bin/env bash

set -euo pipefail

# Starts the healthcheck server in the background

socat \
    -v -d -d \
    TCP-LISTEN:"$HBASE_HEALTHCHECK_PORT",reuseaddr,fork \
    SYSTEM:"hbase2-docker-healthcheck html" &

pid="$!"
disown -h

echo >&2 "INFO: healthcheck server running on port $HBASE_HEALTHCHECK_PORT (pid: $pid)"
