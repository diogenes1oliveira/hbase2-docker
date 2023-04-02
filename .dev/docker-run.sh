#!/usr/bin/env bash
# shellcheck disable=SC1091

set -uo pipefail

IMAGE_NAME="${IMAGE_NAME:-diogenes1oliveira/hbase2-docker}"
CONTAINER_NAME="${CONTAINER_NAME:-hbase2-docker}"
DOCKER="${DOCKER:-docker}"
DOCKER_MODE="${DOCKER_MODE:--d}"
DOCKER_RUN_OPTS="${DOCKER_RUN_OPTS:-}"
HBASE_PORT_MAPPINGS='2181:2181 16000:16000 16010:16010 16020:16020 16030:16030'

CMD_ARGS=( "$@" )
CMD_DOCKER_RUN=()

main() {
    build_docker_cmd

    echo >&2 "$ ${CMD_DOCKER_RUN[*]}"
    "${CMD_DOCKER_RUN[@]}"
}

# shellcheck disable=SC2120
build_docker_cmd() {
    eval set -- "$DOCKER"
    CMD_DOCKER_RUN=( "$@" run --rm "$DOCKER_MODE" --name "$CONTAINER_NAME" )

    if [ -e .docker.env ]; then
        CMD_DOCKER_RUN+=( --env-file .docker.env )
        read_port_mappings
    fi

    for spec in $( bin/tcp-map-ports --echo "$HBASE_PORT_MAPPINGS" ); do
        IFS=: read -r listen_port target_port <<<"$spec"
        # reversed when binding in Docker
        CMD_DOCKER_RUN+=( -p "$target_port:$listen_port" )
    done

    eval set -- "$DOCKER_RUN_OPTS"
    CMD_DOCKER_RUN+=( "$@" )

    CMD_DOCKER_RUN+=( "$IMAGE_NAME" "${CMD_ARGS[@]}")
}

read_port_mappings() {
    docker_env_mappings="$(
        unset HBASE_PORT_MAPPINGS
        source bin/dotenv-load .docker.env
        printf '%s' "${HBASE_PORT_MAPPINGS:-}"
    )"
    if [ -n "$docker_env_mappings" ]; then
        HBASE_PORT_MAPPINGS="$docker_env_mappings"
    fi
}

main

