#!/usr/bin/env bash
set -euo pipefail
SCRIPT="${BASH_SOURCE[0]:-$0}"

usage() {
    cat <<eof
Starts HBase in standalone or cluster mode

Usage:
    ${SCRIPT}

Environment variables:
    \$SERVICE_PRECONDITIONS   space-separated list of HOST:PORT to wait for
    \$HBASE_HOME              root of HBase installation (default: /opt/hbase-current)
    \$JAVA_HOME               path to a Java installation (default: /usr)
    \$HBASE_ROLE              master, regionserver or standalone (default: standalone)
eof
}

main() {
    args_parse "$@"

    hbase_wait_for_servers "${SERVICE_PRECONDITIONS:-}"

    case "${HBASE_ROLE}" in
    standalone )
        STARTED=true
        trap hbase_standalone_stop SIGINT
        trap hbase_standalone_stop SIGTERM
        hbase_standalone_start "$@"
        ;;
    master | regionserver )
        "${HBASE_HOME}/bin/hbase" "${HBASE_ROLE}" start "$@"
        ;;
    * )
        echo >&2 "ERROR: invalid \$HBASE_ROLE: '${HBASE_ROLE}'"
        return 1
    esac
}

hbase_wait_for_servers() (
    cd "$(dirname "$(realpath "${SCRIPT}")")"
    eval set -- "$1"
    ./wait-for-it.sh "$@"
)

hbase_standalone_start() {

    if ! "${HBASE_HOME}/bin/start-hbase.sh" "$@"; then
        hbase_standalone_log ERROR 'HBase failed to start'
        STARTED=false
        exit 1
    fi

    sleep 5 &
    BACKGROUND_PID="$!"
    wait "${BACKGROUND_PID}"

    hbase_standalone_log INFO 'HBase started'

    tail --retry -n +0 -f "${HBASE_HOME}"/logs/* &
    BACKGROUND_PID="$!"
    wait "${BACKGROUND_PID}"
}

hbase_standalone_stop() {
    hbase_standalone_log INFO 'HBase requested to stop'

    if [ "${STARTED}" = 'true' ]; then
        set +e
        "${HBASE_HOME}/bin/stop-hbase.sh"
        code="$?"
        set -e
    else
        code=0
    fi

    if [ -n "${BACKGROUND_PID:-}" ]; then
        kill -9 "${BACKGROUND_PID}" || true
    fi

    hbase_standalone_log INFO "HBase stopped with status ${code}"
    exit "${code}"
}

hbase_standalone_log() {
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

    HBASE_HOME="$(realpath "${HBASE_HOME:-/opt/hbase-current}")"
    export HBASE_HOME
    export JAVA_HOME="${JAVA_HOME:-/usr}"
    export HBASE_ROLE="${HBASE_ROLE:-standalone}"
}

main "$@"
