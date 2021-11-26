#!/usr/bin/env bash
set -euo pipefail
SCRIPT="${BASH_SOURCE[0]:-$0}"

usage() {
    cat <<eof
Extracts the HBase files from the image into a local path

This command starts a container mounted with the local path, copying the
HBase files into it and fixing up the UID and GID

Usage:
    ${SCRIPT} HBASE_PREFIX
    HBASE_PREFIX=/some/path ${SCRIPT}

Options:
    \$HBASE_PREFIX  directory to extract the files into. For safety reasons,
                    this must contain 'hbase' somewhere in the effective name

Environment variables:
    \$DOCKER        Docker command (default: 'docker')
eof
}

declare -a ARGS
declare -a ARGS_PRINTABLE

function main {
    prepare_output_path
    build_args

    echo "$ ${ARGS_PRINTABLE[@]}"
    exec "${ARGS[@]}"
}

function prepare_output_path {
    mkdir -p "${HBASE_PREFIX}"
    OUTPUT="$(realpath "${HBASE_PREFIX}")"

    if [[ "${EUID}" == '0' || "${UID}" == '0' ]] && [ "${DANGEROUSLY_RUN_AS_ROOT:-}" != 'true' ]; then
        echo >&2 "ERROR: running as root! Run as your regular user or export DANGEROUSLY_RUN_AS_ROOT=true if you're okay with that."
        exit 1
    fi

    if [[ "${HBASE_PREFIX}" != *hbase* ]]; then
        echo >&2 "ERROR: no 'hbase' in the output path"
        exit 1
    fi

    if [ "${HBASE_PREFIX}" = "$(getent passwd "${UID}" | cut -d: -f6)" ] && [ "${DANGEROUSLY_RUN_IN_HOME:-}" != 'true' ]; then
        echo >&2 "ERROR: output path is your home folder! Change it or export DANGEROUSLY_RUN_IN_HOME=true if you're okay with that."
        exit 1
    fi

    rm -rf "${HBASE_PREFIX}"/*
}

function go_to_repo_root {
    cd "$(realpath "$(dirname "${SCRIPT}")")"
    cd ..
}

function build_args {
    go_to_repo_root
    image_name="$( make -s print-image-name )"

    eval set -- "${DOCKER}"
    set -euo pipefail

    ARGS=(
        "$@" run --rm --user root --entrypoint /bin/bash
        -v "${HBASE_PREFIX}:/app" -w /app 
        "${image_name}"
        -c "
            rm -rf /app/* && \
            cp -r /opt/hbase-current/* /app && \
            cp -r /app/conf /app/conf.bkp && \
            chown ${UID}:$(id -g) -R /app
        "
    )

    for arg in "${ARGS[@]}"; do
        printable=$( ./bin/shell-pprint.sh <<<"${arg}" )
        ARGS_PRINTABLE+=( "${printable}" )
    done
}

case "${1:-}" in
-h | --help )
    usage
    exit 0
    ;;
esac

HBASE_PREFIX="${1:-${HBASE_PREFIX:-}}"
DOCKER="${DOCKER:-docker}"

if [ -z "${HBASE_PREFIX}" ]; then
    usage >&2
    echo >&2
    echo >&2 "ERROR: no output path"
    exit 1
fi

main
