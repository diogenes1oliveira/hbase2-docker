#!/usr/bin/env bash

function set_env {
    while ! [ -e Makefile ]; do
        if [ "$(pwd)" = '/' ]; then
            echo >&2 "ERROR: no Makefile found in the directory hierarchy"
            return 1
        fi
        cd ..
    done

    export VCS_REF="test-bats-local"
    export DOCKER_COMPOSE="docker-compose -p test-bats-local -f ../docker-compose.yml"
    export CONTAINER_NAME="test-bats-local"
    export IMAGE_NAME="$(make -s print-image-name)"
}

function docker_build {
    set_env
    make -s build
}

function docker_cleanup {
    set_env
    docker rm -f "${CONTAINER_NAME}" || true

    unset HBASE_CONF_hbase_master_port
    unset HBASE_CONF_hbase_master_info_port
    unset HBASE_CONF_hbase_regionserver_port
    unset HBASE_CONF_hbase_regionserver_info_port
}

function hbase_extract {
    set_env
    mkdir -p ./var/hbase/
    (
        cd ./var/hbase/
        export GID="$(id -g)"

        echo '$ docker' run --rm -i -v "'${PWD}:/app'" -w /app "'${IMAGE_NAME}'" /bin/bash '<<'

        docker run --rm -i -v "${PWD}:/app" -w /app "${IMAGE_NAME}" /bin/bash <<<"
            cp -r /opt/hbase-current/* /app
            chown ${UID}:${GID} -R /app
        "
    )
}

function hbase_shell {
    (
        export JAVA_HOME="${JAVA_HOME:-/usr}"
        ./var/hbase/bin/hbase shell -n <<<"$@" 2>&1 | sed \
            -e '/^WARNING:/d' \
            -e '/^INFO:/d' \
            -e '/^OpenJDK 64-Bit/d' \
            -e '/^unsupported Java/d' \
            -e '/util.NativeCodeLoader:/d'
    )
}

function hbase_scan {
    table="$1"
    shift
    hbase_shell "scan '${table}' $*" | tr '\n' ' ' | sed 's/  */ /g'
}

function hbase_start {
    make -s rm || true
    make -s run
}

function do_retry {
    local max="$1"
    [ "${max}" -gt 0 ]
    local i=0
    shift
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

function find_in_hierarchy {
    path="${1:-}"

    (
        while ! [ -e "${path}" ]; do
            if [ "$(pwd)" = '/' ]; then
                echo >&2 "ERROR: script not found in the hierarchy"
                return 1
            fi
            cd ..
        done

        realpath "${path}"
    )
}

if [ -z "${BATS_RUN_TMPDIR:-}" ]; then
    # Execute the named function if this file is called directly
    set -euo pipefail
    cd "$(dirname "$(realpath "$0")")"
    "$@"
fi
