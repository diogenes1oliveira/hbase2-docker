#!/usr/bin/env bats

export TEST="$(uuidgen | sha256sum | head -c 10)"
export VCS_REF="test-bats-${TEST}"
export DOCKER_COMPOSE="docker-compose -p test-bats-${TEST} -f ../docker-compose.yml"
export CONTAINER_NAME="test-bats-${TEST}"
IMAGE_NAME="$(make print-image-name)"

setup() {
    make build
}

teardown() {
    unset HBASE_CONF_hbase_master_port
    unset HBASE_CONF_hbase_master_info_port
    unset HBASE_CONF_hbase_regionserver_port
    unset HBASE_CONF_hbase_regionserver_info_port

    docker rm -f "${CONTAINER_NAME}" || true
    docker image rm "${IMAGE_NAME}" || true
}
