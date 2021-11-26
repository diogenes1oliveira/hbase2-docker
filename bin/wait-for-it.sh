#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$0"

usage() {
    cat <<eof
Waits for a remote server to become available

Usage:
    ${SCRIPT} [-q] [-i DURATION] [-m MAX_TRIES] [ HOST:PORT ...]

Options:
    -q, --quiet         Quiet mode
    -i, --interval      Duration in seconds between each retry (default: 2)
    -m, --max-tries     Max number of retries (default: 50)
    HOST:PORT           Host/port to check a TCP connection

Environment variables:
    WAIT_FOR_IT_OPTS    Extra arguments to prepend to the command line
eof
}

main() {
    args_parse "$@"

    for service in "${SERVICES[@]}"; do
        wait_for_service "${service}"
    done
}

wait_for_service() {
    service="$1"

    pattern='([^:]+):([0-9]+)'
    if [[ "${service}" =~ ${pattern} ]]; then
        host="${BASH_REMATCH[1]}"
        port="${BASH_REMATCH[2]}"
    else
        args_error "Invalid service ${service}"
    fi

    log_info "Waiting for ${host} on port ${port}"

    i=1

    until tcp_test "${host}" "${port}"; do
        log_info "[${i}/${MAX_TRIES}] ${host}:${port} is not available yet"
        if [ "${i}" -ge "${MAX_TRIES}" ]; then
            log_info "[${i}/${MAX_TRIES}] ${host}:${port} is still not available; giving up after ${i} tries"
            return 1
        fi

        log_info "[${i}/${MAX_TRIES}] try once again in ${INTERVAL}s..."
        i="$((i+1))"
        sleep "${INTERVAL}"
    done

    log_info "[$i/${MAX_TRIES}] ${host}:${port} is available."
}

tcp_test() {
    host="$1"
    port="$2"

    nc "${NC_OPTS[@]+"${NC_OPTS[@]}"}" -z "${host}" "${port}"
}

args_error() {
    usage >&2
    echo >&2
    echo >&2 "ERROR: $*"
    exit 1
}

args_parse() {
    original_args=( "$@" )
    eval set -- "${WAIT_FOR_IT_OPTS:-}"
    args=( "$@" )

    set +u
    args+=( "${original_args[@]+"${original_args[@]}"}" )
    set -u

    if ! OPTS="$(getopt -l 'help,quiet,interval:,max-tries:' -o 'hqi:m:' -- "${args[@]}")"; then
        args_error 'failed to parse args'
    fi

    eval set -- "${OPTS}"
    INTERVAL=2
    MAX_TRIES=50
    NC_OPTS=( -v )
    VERBOSE=true

    while true; do
        case "${1:-}" in
        -h | --help )
            usage && exit 0 ;;
        -q | --quiet )
            declare -a NC_OPTS && VERBOSE=false && shift ;;
        -i | --interval )
            INTERVAL="${2:-}" && shift 2 ;;
        -m | --max-tries )
            MAX_TRIES="${2:-}" && shift 2 ;;
        -- )
            shift && break ;;
        * )
            args_error "Unknown argument ${1:-}"
        esac
    done

    if ! [ "${INTERVAL}" -gt 0 ]; then
        args_error "Interval must be positive"
    fi

    if ! [ "${MAX_TRIES}" -gt 0 ]; then
        args_error "Max tries must be positive"
    fi

    SERVICES=( "$@" )
}

log_info() {
    if [ "${VERBOSE}" = 'true' ]; then
        echo >&2 "INFO: $*"
    fi
}

main "$@"
