#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$0"

usage() {
    cat <<eof
Stops the standalone HBase container

Usage:
    ${SCRIPT} [ -k | --kill ]

Options:
    -k, --kill    kill the container at once

Environment variables:
    \$HBASE_CONTAINER_NAME   name of the container (default: 'hbase2-docker')
    \$DOCKER_STOP_OPTS       extra options for docker stop (default: '-t60')
    \$DOCKER                 Docker command (default: 'docker')
eof
}

HBASE_CONTAINER_NAME="${HBASE_CONTAINER_NAME:-hbase2-docker}"
DOCKER="${DOCKER:-docker}"
DOCKER_STOP_OPTS="${DOCKER_STOP_OPTS:--t60}"
KILL=

declare -a STOP_ARGS
declare -a PS_ARGS

function main {
    build_args "$@"

    if ! ( "${PS_ARGS[@]}" | grep -q "${HBASE_CONTAINER_NAME}" ); then
        echo >&2 "INFO: container is not running"
    else
        echo >&2 "$ ${STOP_ARGS[*]}"
        exec "${STOP_ARGS[@]}"
    fi
}

function build_args {
    eval set -- "${DOCKER}"

    STOP_ARGS=( "$@" )
    PS_ARGS=( "$@" ps )

    if [ "${KILL}" != 'true' ]; then
        STOP_ARGS+=( stop "${HBASE_CONTAINER_NAME}" )

        eval set -- "${DOCKER_STOP_OPTS}"
        STOP_ARGS+=( "$@" )
    else
        STOP_ARGS+=( kill "${HBASE_CONTAINER_NAME}" )
    fi

}

# Show help
case "${1:-}" in
-h | --help )
    usage
    exit 0
    ;;
-k | --kill )
    KILL=true
    shift
    ;;
esac

main "$@"
