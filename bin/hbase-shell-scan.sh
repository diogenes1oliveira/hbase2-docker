#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$0"

usage() {
    cat <<eof
Executes a HBase scan command

Usage:
    ${SCRIPT} [-l | --full-log] TABLE [...ARGS]

Options:
    -l, --full-log      don't to remove some useless HBase log data
    TABLE               name of the table to be scanned
    ARGS                extra arguments to be passed to scan
    \$HBASE_PREFIX      root HBase installation directory
                        (default: REPO_ROOT/var/hbase)
    \$JAVA_HOME         path to a Java installation (default: /usr)
eof
}

function main {
    args_parse "$@"
    go_to_bin_root

    CMD="scan '${TABLE}'"

    for arg in "${ARGS[@]}"; do
        CMD="${CMD}, ${arg}"
    done

    ./hbase-shell-run.sh "${SHELL_ARGS[@]+"${SHELL_ARGS[@]}"}" "${CMD}"

}

function go_to_bin_root {
    cd "$(realpath "$(dirname "${SCRIPT}")")"
}

function args_parse {
    if ! OPTS="$( getopt -l 'help,full-log' -o 'hl' -- "$@" )"; then
        args_error "failed to parse args"
    fi

    declare -a SHELL_ARGS
    eval set -- "${OPTS}"
    set -euo pipefail

    for arg in "$@"; do
        case "${arg}" in
        -h | --help )
            usage
            exit 0 ;;
        -l | --full-log )
            SHELL_ARGS+=( --full-log ) ;;
        (--)
            shift && break ;;
        (*)
            args_error "unknown argument ${arg}"
        esac
        shift
    done

    TABLE="${1:-}"
    if [ -z "${TABLE}" ]; then
        args_error "no TABLE is set"
    fi

    shift
    ARGS=( "$@" )
}

function args_error {
    message="$1"

    usage >&2
    echo >&2
    printf >&2 '%s\n' "ERROR: ${message}"
    exit 1
}

main "$@"
