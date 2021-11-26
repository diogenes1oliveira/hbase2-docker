#!/usr/bin/env bash

function go_to_repo_root {
    cd "${BATS_TEST_DIRNAME}"
    cd ../..
}

function set_hbase_env {
    export HBASE_CONTAINER_NAME="test-bats-local"
    export IMAGE_NAME="$(go_to_repo_root && make -s print-image-name)"
}

function do_with_retry {
    if [[ "${1:-}" =~ ^-m(.+) ]]; then
        max="${BASH_REMATCH[1]}"
        shift 1
    elif [ "${1:-}" = '-m' ]; then
        max="${2:-0}"
        shift 2
    else
        max=10
    fi

    if ! [ "${max}" -gt 0 ]; then
        echo >&2 "ERROR: \$max must be > 0"
        return 1
    fi

    i=0

    while ! "$@"; do
        if [ "$i" -gt "${max}" ]; then
            echo >&2 "ERROR: command $@ failed more than ${max} times"
            return 1
        fi

        i="$((i+1))"

        echo >&2 "INFO: command $@ failed, will try again in 2s"
        sleep 2
    done
}

# Execute the named function if this file is called directly
if [ -z "${BATS_RUN_TMPDIR:-}" ]; then
    set -euo pipefail

    BATS_TEST_DIRNAME="$(dirname "$(realpath "$0")")"
    "$@"
fi
