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
    \$HBASE_HOME              root of HBase installation (default: /opt/hbase)
    \$JAVA_HOME               path to a Java installation (default: /usr)
    \$HBASE_ROLE              master, regionserver or standalone (default: standalone)
eof
}

main() {
    args_parse "$@"

    hbase_wait_for_servers "${SERVICE_PRECONDITIONS:-}"
    hbase_start
}

hbase_wait_for_servers() (
    cd "$(dirname "$(realpath "${SCRIPT}")")"
    eval set -- "$1"

    ./wait-for-it.sh "$@"
)

hbase_start() {
    log_name="hbase-${HBASE_IDENT_STRING}-${HBASE_COMMAND}-${HOSTNAME:-}"
    log_files=(
        "${HBASE_LOG_DIR}/SecurityAuth.audit"
        "${HBASE_LOG_DIR}/${log_name}.out"
        "${HBASE_LOG_DIR}/${log_name}.log"
    )

    set +e
    EXIT_CODE=1

    trap hbase_stop SIGTERM SIGINT SIGQUIT
    trap tail_stop EXIT
    "${HBASE_HOME}"/bin/hbase-daemon.sh start "${HBASE_COMMAND}" "$@"

    tail -q -F "${log_files[@]}" &
    TAIL_PID="$!"
    wait "${TAIL_PID}" || true

    exit "${EXIT_CODE}"
}

hbase_stop() {
    set +e
    "${HBASE_HOME}"/bin/hbase-daemon.sh stop "${HBASE_COMMAND}" "$@"
    EXIT_CODE="$?"
    tail_stop
}

tail_stop() {
    if [ -n "${TAIL_PID}" ]; then
        kill "${TAIL_PID}" || true
        TAIL_PID=
    fi
}

args_parse() {
    case "${1:-}" in
    -h | --help )
        usage && exit 0 ;;
    esac

    HBASE_HOME="$(realpath "${HBASE_HOME:-/opt/hbase}")"
    export HBASE_HOME
    export JAVA_HOME="${JAVA_HOME:-/usr}"
    export HBASE_ROLE="${HBASE_ROLE:-standalone}"
    export HBASE_IDENT_STRING=docker
    export HBASE_LOG_DIR="${HBASE_LOG_DIR:-/var/log/hbase}"
    export HBASE_PID_DIR="${HBASE_PID_DIR:-/var/run/hbase}"
    export HBASE_OPTS="${HBASE_OPTS:-} ${HBASE_LOG_OPTS:-}"

    case "${HBASE_ROLE}" in
    standalone | master )
        HBASE_COMMAND=master ;;
    regionserver )
        HBASE_COMMAND=regionserver ;;
    *)
        echo >&2 "ERROR: Invalid HBASE_ROLE '${HBASE_ROLE}'"
        return 1
        ;;
    esac
}

main "$@"
