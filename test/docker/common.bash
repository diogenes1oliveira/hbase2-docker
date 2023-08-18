#!/usr/bin/env bash

bats_require_minimum_version '1.5.0'

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'

export BATS_TEST_NAME_PREFIX="$(basename "$BATS_TEST_FILENAME"): "

teardown() (
    echo "# INFO: cleaning up docker" >&3

    _docker_compose kill --signal 9 || true
    _docker_compose down --volumes --remove-orphans
    _docker_compose rm --force --stop --volumes
	_docker network prune --force
	_docker volume prune --all --force || _docker volume prune --force

    echo "# INFO: Docker cleaned up" >&3
)

setup_file() {
    echo >&3 "# INFO: executing $BATS_TEST_NAME_PREFIX"
}

_docker_compose() (
    cd "$BATS_TEST_DIRNAME/../.."

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
    local max_tries="$1"

    export DOCKER_COMPOSE="${DOCKER_COMPOSE:-docker compose}"
    export DOCKER="${DOCKER:-docker}"

    export DOCKER_COMPOSE_NAME="$(_docker_compose config --format json | jq -r '.name')"
    export DOCKER_CONTAINER_NAME="$DOCKER_COMPOSE_NAME-hbase-1"

    _docker_compose up --remove-orphans --renew-anon-volumes --detach

    tries=0

    while true; do
        if [ "$tries" -ge "$max_tries" ]; then
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

        echo >&3 "# WARN: container unhealthy ($tries/$max_tries), trying again in 5 seconds"
        sleep 5
    done

}

_hbase_shell() {
    local cmd="$1"
    echo >&3 "# INFO: hbase shell: $cmd"
    _docker_compose exec -T client hbase shell -n 2>&1 <<<"$cmd" | sed 's/^/# /g' >&3
}
