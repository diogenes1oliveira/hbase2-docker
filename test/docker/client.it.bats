#!/usr/bin/env bats

load 'common'

MAX_TRIES=24

function setup {
    cd "$BATS_TEST_DIRNAME"
}

function validate_hbase_commands {
    _hbase_shell 'status'
    _hbase_shell "create 'table', 'f'"
    _hbase_shell "scan 'table'"
}

function validate_healthcheck {
    curl -svf "http://$HBASE2__DOCKER_HOSTNAME:$HBASE_HEALTHCHECK_PORT/"
}

@test 'should connect for localhost and default ports' {
    export HBASE2__DOCKER_HOSTNAME=localhost
    set_env_default_ports

    _docker_compose_up_and_wait "$MAX_TRIES"

    validate_healthcheck
    validate_hbase_commands
}

@test 'should connect for machine hostname and default ports' {
    export HBASE2__DOCKER_HOSTNAME="$(hostname)"
    set_env_default_ports

    _docker_compose_up_and_wait "$MAX_TRIES"

    validate_healthcheck
    validate_hbase_commands
}

@test 'should connect for localhost and random ports' {
    export HBASE2__DOCKER_HOSTNAME=localhost
    set_env_random_ports

    _docker_compose_up_and_wait "$MAX_TRIES"

    validate_healthcheck
    validate_hbase_commands
}

@test 'should connect for machine hostname and random ports' {
    export HBASE2__DOCKER_HOSTNAME="$(hostname)"
    set_env_random_ports

    _docker_compose_up_and_wait "$MAX_TRIES"

    validate_healthcheck
    validate_hbase_commands
}

set_env_default_ports() {
    unset HBASE_PORT_MAPPINGS
    unset HBASE_SITE_HBASE_MASTER
    unset HBASE_SITE_HBASE_MASTER_HOSTNAME
    unset HBASE_SITE_HBASE_ZOOKEEPER_QUORUM
    unset HBASE_SITE_HBASE_REGIONSERVER_HOSTNAME

    export HBASE_SITE_HBASE_ZOOKEEPER_PROPERTY_CLIENT___PORT=2181
    export HBASE_SITE_HBASE_MASTER_PORT=16000
    export HBASE_SITE_HBASE_MASTER_INFO_PORT=16010
    export HBASE_SITE_HBASE_REGIONSERVER_PORT=16020
    export HBASE_SITE_HBASE_REGIONSERVER_INFO_PORT=16030
    export HBASE_HEALTHCHECK_PORT=17000
}

set_env_random_ports() {
    unset HBASE_PORT_MAPPINGS
    unset HBASE_SITE_HBASE_MASTER
    unset HBASE_SITE_HBASE_MASTER_HOSTNAME
    unset HBASE_SITE_HBASE_ZOOKEEPER_QUORUM
    unset HBASE_SITE_HBASE_REGIONSERVER_HOSTNAME

    export HBASE_SITE_HBASE_ZOOKEEPER_PROPERTY_CLIENT___PORT="$(../../.dev/tcp-get-free-port.sh 18000)"
    export HBASE_SITE_HBASE_MASTER_PORT="$(../../.dev/tcp-get-free-port.sh "$((HBASE_SITE_HBASE_ZOOKEEPER_PROPERTY_CLIENT___PORT+1))")"
    export HBASE_SITE_HBASE_MASTER_INFO_PORT="$(../../.dev/tcp-get-free-port.sh "$((HBASE_SITE_HBASE_MASTER_PORT+1))")"
    export HBASE_SITE_HBASE_REGIONSERVER_PORT="$(../../.dev/tcp-get-free-port.sh "$((HBASE_SITE_HBASE_MASTER_INFO_PORT+1))")"
    export HBASE_SITE_HBASE_REGIONSERVER_INFO_PORT="$(../../.dev/tcp-get-free-port.sh "$((HBASE_SITE_HBASE_REGIONSERVER_PORT+1))")"
    export HBASE_HEALTHCHECK_PORT="$(../../.dev/tcp-get-free-port.sh "$((HBASE_SITE_HBASE_REGIONSERVER_INFO_PORT+1))")"
}
