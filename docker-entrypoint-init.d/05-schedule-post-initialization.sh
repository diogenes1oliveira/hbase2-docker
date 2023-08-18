#!/usr/bin/env bash

set -euo pipefail
SCRIPT="${BASH_SOURCE[0]:-$0}"

# Schedules the command to be run after the healthcheck succeeds

function _schedule_post_initialization {
    local url="http://localhost:$HBASE_HEALTHCHECK_PORT/"

    sleep 3

    while ! curl -sf "$url" >/dev/null; do
        _do_log WARN "container still not healthy, will try $url again in 3s..."
        sleep 3
    done

    echo >&2 "INFO: container is healthy"

    if [ -n "${HBASE_POST_INITIALIZATION_COMMAND:-}" ]; then
        echo >&2 "INFO: executing post-initialization command"
        _run_post_initialization_command || echo >&2 "ERROR: failed to execute post-initialization command"
    fi

}

function _run_post_initialization_command {
    if [ -e "${HBASE_POST_INITIALIZATION_COMMAND:-}" ]; then
        hbase shell -n < "$HBASE_POST_INITIALIZATION_COMMAND"
    else
        hbase shell -n <<<"$HBASE_POST_INITIALIZATION_COMMAND"
    fi

    echo >&2 "INFO: post-initialization command executed succesfully"
}

function _do_log (
    local IFS=' '
    local level="$1"
    shift
    echo >&2 "$(date -u '+%Y-%m-%dT%H:%M:%SZ') $level [$SCRIPT] : $*..."
)

_schedule_post_initialization &
pid="$!"
disown -h

echo >&2 "INFO: waiting for container to become healthy"
