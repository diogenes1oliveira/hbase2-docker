#!/usr/bin/env bats

load 'common'


setup() {
    export HBASE_SITE_hbase_zookeeper_property_clientPort="$(.dev/tcp-get-free-port.sh 18000)"
    export HBASE_SITE_hbase_master_port="$(.dev/tcp-get-free-port.sh "$((HBASE_SITE_hbase_zookeeper_property_clientPort+1))")"
    export HBASE_SITE_hbase_master_info_port="$(.dev/tcp-get-free-port.sh "$((HBASE_SITE_hbase_master_port+1))")"
    export HBASE_SITE_hbase_regionserver_port="$(.dev/tcp-get-free-port.sh "$((HBASE_SITE_hbase_master_info_port+1))")"
    export HBASE_SITE_hbase_regionserver_info_port="$(.dev/tcp-get-free-port.sh "$((HBASE_SITE_hbase_regionserver_port+1))")"
    export HBASE_PORT_MAPPINGS="
        2181:$HBASE_SITE_hbase_zookeeper_property_clientPort
        16000:$HBASE_SITE_hbase_master_port
        16010:$HBASE_SITE_hbase_master_info_port
        16020:$HBASE_SITE_hbase_regionserver_port
        16030:$HBASE_SITE_hbase_regionserver_info_port
    "
}

teardown() {
    _docker_compose kill -s 9 || true
    _docker_compose rm -fsv
	_docker volume prune --all -f
	_docker network prune -f
}

@test 'should connect for localhost and random ports' {
    export HBASE_DOCKER_HOSTNAME=localhost
    _docker_compose_up_and_wait

    _hbase_shell 'status'
    _hbase_shell "create 'table', 'f'"
    _hbase_shell "scan 'table'"
}

@test 'should connect for machine hostname and random ports' {
    export HBASE_DOCKER_HOSTNAME="$(hostname)"
    echo >&3 "# INFO: export HBASE_DOCKER_HOSTNAME=$HBASE_DOCKER_HOSTNAME"
    _docker_compose_up_and_wait

    _hbase_shell 'status'
    _hbase_shell "create 'table', 'f'"
    _hbase_shell "scan 'table'"
}