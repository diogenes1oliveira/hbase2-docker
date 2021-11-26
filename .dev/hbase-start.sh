#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$0"

usage() {
    cat <<eof
Starts the standalone HBase container in the background

This command will automatically map the ports and inject the HBASE_CONF_
variables

Usage:
    ${SCRIPT}

Environment variables:
    \$HBASE_CONTAINER_NAME   name of the container (default: 'hbase2-docker')
    \$DOCKER_RUN_OPTS        extra options to pass to docker run
    \$DOCKER                 Docker command (default: 'docker')
eof
}

# Arrays to store the arguments
ORIGINAL_ARGS=( "$@" )
declare -a ARGS

# Variables with ports to be bound
PORT_ENV_NAMES=(
    HBASE_CONF_hbase_zookeeper_property_clientPort
    HBASE_CONF_hbase_master_port
    HBASE_CONF_hbase_master_info_port
    HBASE_CONF_hbase_regionserver_port
    HBASE_CONF_hbase_regionserver_info_port
)

main() {
    go_to_repo_root
    args_parse "$@"
    build_command_start "$@"
    add_env_mappings
    add_port_mappings

    ARGS+=( "${IMAGE_NAME}" "${ORIGINAL_ARGS[@]+"${ORIGINAL_ARGS[@]}"}" )
    echo "$ ${ARGS[*]}"
    exec "${ARGS[@]}"
}

build_command_start() {
    eval set -- "${DOCKER}"
    ARGS+=( "$@" run -d --rm --name "${HBASE_CONTAINER_NAME}" )

    eval set -- "${DOCKER_RUN_OPTS}"
    ARGS+=( "$@" )
}

add_port_mappings() {
    while read -r port; do
        ARGS+=( -p "${port}:${port}" )
    done < <(
        set -euo pipefail

        for port_env_name in "${PORT_ENV_NAMES[@]}"; do
            port="${!port_env_name}"
            if [ "${port}" -le 0 ]; then
                args_error "Bad port in ${port_env_name}: ${port}"
            fi
            printf '%s\n' "${port}"
        done
    )
}

args_error() {
    echo >&2 "ERROR: $*"
    exit 1
}

add_env_mappings() {
    source ./bin/hbase-config-build.sh env

    # Passthrough HBASE_CONF_ environment variables
    while read -r env_name; do
        ARGS+=( -e "${env_name}" )
    done < <( awk 'BEGIN{for(v in ENVIRON) print v}' | grep HBASE_CONF_ )
}

go_to_repo_root() {
    cd "$(dirname "$(realpath "$0")")"
    cd ..
}

args_parse() {
    case "${1:-}" in
    -h | --help )
        usage
        exit 0
        ;;
    esac

    HBASE_CONTAINER_NAME="${HBASE_CONTAINER_NAME:-hbase2-docker}"
    DOCKER_RUN_OPTS="${DOCKER_RUN_OPTS:-}"
    DOCKER="${DOCKER:-docker}"
    IMAGE_NAME="$(make -s print-image-name)"
}

main "$@"
