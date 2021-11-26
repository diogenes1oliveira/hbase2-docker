#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$0"

usage() {
    cat <<eof
Executes a HBase command within the shell

Usage:
    ${SCRIPT} [-l | --full-log] COMMAND
    COMMAND='hbase command' TRIM=true ${SCRIPT}

Options:
    -l, --full-log      don't to remove some useless HBase log data
    \$COMMAND           commands to be executed
                        precedence is argument > environment variable
    \$HBASE_PREFIX      root HBase installation directory
                        (default: REPO_ROOT/var/hbase)
    \$JAVA_HOME         path to a Java installation (default: /usr)
eof
}

function main {
    args_parse "$@"
    hbase_home_set
    
    if [ -z "${COMMAND}" ]; then
        hbase_terminal "$@"
    elif [ "${FULL_LOG}" != 'true' ]; then
        hbase_terminal -n <<<"${COMMAND}" 2>&1 | hbase_trim
    else
        hbase_terminal -n <<<"${COMMAND}"
    fi
}

function go_to_repo_root {
    cd "$(realpath "$(dirname "${SCRIPT}")")"
    cd ..
}

function hbase_terminal {
    "${HBASE_PREFIX}/bin/hbase" shell "$@"
}

function hbase_trim {
    sed \
        -e '/^WARNING:/d' \
        -e '/^INFO:/d' \
        -e '/^OpenJDK 64-Bit/d' \
        -e '/^unsupported Java/d' \
        -e '/util.NativeCodeLoader:/d'
}

function hbase_home_set {
    if [ -n "${HBASE_PREFIX:-}" ]; then
        HBASE_PREFIX="$(realpath "${HBASE_PREFIX}")"
    fi

    go_to_repo_root

    if [ -z "${HBASE_PREFIX:-}" ]; then
        HBASE_PREFIX="$(pwd)/var/hbase"
    fi
}

function args_error {
    message="$1"

    usage >&2
    echo >&2
    printf >&2 '%s\n' "ERROR: ${message}"
    exit 1
}

function args_parse {
    export JAVA_HOME="${JAVA_HOME:-/usr}"
    TRIM="${TRIM:-}"

    if ! OPTS="$( getopt -l 'help,full-log' -o 'hl' -- "$@" )"; then
        args_error "failed to parse args"
    fi

    FULL_LOG=

    eval set -- "${OPTS}"
    set -euo pipefail

    for arg in "$@"; do
        case "${arg}" in
        -h | --help )
            usage
            exit 0 ;;
        -l | --full-log )
            FULL_LOG=true ;;
        (--)
            shift && break ;;
        (*)
            args_error "unknown argument ${arg}" ;;
        esac
        shift
    done

    COMMAND="${1:-${COMMAND:-}}"
}

main "$@"
