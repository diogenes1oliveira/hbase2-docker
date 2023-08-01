#!/usr/bin/env bash

bats_require_minimum_version '1.5.0'

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'

cd "$BATS_TEST_DIRNAME/../.."
export BATS_TEST_NAME_PREFIX="$(basename "$BATS_TEST_FILENAME"): "

setup_file() {
    echo >&3 "# INFO: executing $BATS_TEST_NAME_PREFIX"
}

_docker_compose() (
    args=( "$@" )
    eval set -- "$DOCKER_COMPOSE"
    "$@" "${args[@]}"
)

_docker() (
    args=( "$@" )
    eval set -- "$DOCKER"
    "$@" "${args[@]}"
)

_docker_compose_up_and_wait() {
    _docker_compose up --remove-orphans --renew-anon-volumes --detach

    tries=0

    while true; do
        if [ "$tries" -ge "$TEST_MAX_TRIES" ]; then
            echo >&3 "# ERROR: container still unhealthy after $tries tries"
            _docker inspect --format '{{ json .State.Health }}' "$DOCKER_CONTAINER_NAME" 2>&1 | sed 's/^/# /g' >&3
            return 1
        fi
        tries="$((tries + 1))"

        run _docker inspect --format '{{ .State.Health.Status }}' "$DOCKER_CONTAINER_NAME"
        assert_success

        if [ "$output" = 'healthy' ]; then
            echo >&3 "# INFO: container is healthy after $tries tries"
            return 0
        fi

        echo >&3 "# WARN: container unhealthy ($tries/$TEST_MAX_TRIES), trying again in 5 seconds"
        sleep 5
    done

}

_hbase_shell() {
    local cmd="$1"
    echo >&3 "# INFO: hbase shell: $cmd"
    _docker_compose exec -T client hbase shell -n 2>&1 <<<"$cmd" | sed 's/^/# /g' >&3
}

export DOCKER_COMPOSE="${DOCKER_COMPOSE:-docker compose}"
export DOCKER="${DOCKER:-docker}"

export DOCKER_COMPOSE_NAME="$(_docker_compose config --format json | jq -r '.name')"
export DOCKER_CONTAINER_NAME="$DOCKER_COMPOSE_NAME-hbase-1"

export TEST_MAX_TRIES=24
