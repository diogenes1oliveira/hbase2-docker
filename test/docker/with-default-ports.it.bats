#!/usr/bin/env bats

load 'common'


setup() {
    export HBASE_SITE_hbase_zookeeper_property_clientPort=2181
    export HBASE_SITE_hbase_master_port=16000
    export HBASE_SITE_hbase_master_info_port=16010
    export HBASE_SITE_hbase_regionserver_port=16020
    export HBASE_SITE_hbase_regionserver_info_port=16030
}

teardown() {
    _docker_compose kill --signal 9 || true
    _docker_compose down --volumes --remove-orphans
    _docker_compose rm --force --stop --volumes
	_docker network prune --force
	_docker volume prune --all --force || _docker volume prune --force
}

@test 'should connect for localhost and default ports' {
    export HBASE_DOCKER_HOSTNAME=localhost
    _docker_compose_up_and_wait

    _hbase_shell 'status'
    _hbase_shell "create 'table', 'f'"
    _hbase_shell "scan 'table'"
}

@test 'should connect for machine hostname and default ports' {
    export HBASE_DOCKER_HOSTNAME="$(hostname)"
    echo >&3 "# INFO: export HBASE_DOCKER_HOSTNAME=$HBASE_DOCKER_HOSTNAME"
    _docker_compose_up_and_wait

    _hbase_shell 'status'
    _hbase_shell "create 'table', 'f'"
    _hbase_shell "scan 'table'"
}
