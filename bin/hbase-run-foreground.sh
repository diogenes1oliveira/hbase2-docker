#!/usr/bin/env bash
set -euo pipefail
SCRIPT="${BASH_SOURCE[0]:-$0}"

usage() {
    cat <<eof
Starts HBase, following the logs until SIGTERM or SIGINT

Usage:
    ${SCRIPT}

Environment variables:
    \$HBASE_WAIT_FOR   space-separated list of HOST:PORT to wait for
    \$HBASE_PREFIX     root of HBase installation (default: /opt/hbase-current)
    \$JAVA_HOME        path to a Java installation (default: /usr)
eof
}

main() {
    args_parse "$@"

    hbase_wait_for_servers

    STARTED=true
    trap hbase_stop SIGINT
    trap hbase_stop SIGTERM

    if ! "${HBASE_PREFIX}/bin/start-hbase.sh" "$@"; then
        log ERROR 'HBase failed to start'
        STARTED=false
        exit 1
    fi

    sleep 5 &
    BACKGROUND_PID="$!"
    wait "${BACKGROUND_PID}"

    log INFO 'HBase started'

    tail --retry -n +0 -f "${HBASE_PREFIX}"/logs/* &
    BACKGROUND_PID="$!"
    wait "${BACKGROUND_PID}"
}

hbase_wait_for_servers() (
    cd "$(dirname "$(realpath "${SCRIPT}")")"
    ./wait-for-it.sh "${HBASE_WAIT_FOR[@]+"${HBASE_WAIT_FOR[@]}"}"
)

hbase_stop() {
    log INFO 'HBase requested to stop'

    if [ "${STARTED}" = 'true' ]; then
        set +e
        "${HBASE_PREFIX}/bin/stop-hbase.sh"
        code="$?"
        set -e
    else
        code=0
    fi

    if [ -n "${BACKGROUND_PID:-}" ]; then
        kill -9 "${BACKGROUND_PID}" || true
    fi

    log INFO "HBase stopped with status ${code}"
    exit "${code}"
}

log() {
    level="$1"
    shift

    ( echo; echo; echo ) >&2
    echo >&2 '################################'

    IFS=' ' printf >&2 '%s: %s\n' "${level}(${SCRIPT})" "$*"

    echo >&2 '################################'
    ( echo; echo; echo ) >&2
}


args_parse() {
    case "${1:-}" in
    -h | --help )
        usage && exit 0 ;;
    esac

    SERVERS_TO_WAIT_FOR=( "$@" )
    export HBASE_PREFIX="$(realpath "${HBASE_PREFIX:-/opt/hbase-current}")"
    export JAVA_HOME="${JAVA_HOME:-/usr}"
}

main "$@"
