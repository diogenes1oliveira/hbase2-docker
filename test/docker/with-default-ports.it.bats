#!/usr/bin/env bats

load 'common'


setup() {
    export HBASE_SITE_hbase_zookeeper_property_clientPort=2181
    export HBASE_SITE_hbase_master_port=16000
    export HBASE_SITE_hbase_master_info_port=16010
    export HBASE_SITE_hbase_regionserver_port=16020
    export HBASE_SITE_hbase_regionserver_info_port=16030
    export HBASE_PORT_MAPPINGS=''
}

teardown() {
    _docker_compose kill -s 9 || true
    _docker_compose rm -fsv
	_docker volume prune --all -f
	_docker network prune -f
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
    _docker_compose_up_and_wait

    _hbase_shell 'status'
    _hbase_shell "create 'table', 'f'"
    _hbase_shell "scan 'table'"
}
