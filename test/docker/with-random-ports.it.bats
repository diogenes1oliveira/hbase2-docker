#!/usr/bin/env bats

load 'common'


setup() {
    export HBASE_SITE_hbase_zookeeper_property_clientPort="$(.dev/tcp-get-free-port.sh 18000)"
    export HBASE_SITE_hbase_master_port="$(.dev/tcp-get-free-port.sh "$((HBASE_SITE_hbase_zookeeper_property_clientPort+1))")"
    export HBASE_SITE_hbase_master_info_port="$(.dev/tcp-get-free-port.sh "$((HBASE_SITE_hbase_master_port+1))")"
    export HBASE_SITE_hbase_regionserver_port="$(.dev/tcp-get-free-port.sh "$((HBASE_SITE_hbase_master_info_port+1))")"
    export HBASE_SITE_hbase_regionserver_info_port="$(.dev/tcp-get-free-port.sh "$((HBASE_SITE_hbase_regionserver_port+1))")"
}

@test 'should connect for localhost and random ports' {
    export HBASE2__DOCKER_HOSTNAME=localhost
    _docker_compose_up_and_wait

    _hbase_shell 'status'
    _hbase_shell "create 'table', 'f'"
    _hbase_shell "scan 'table'"
}

@test 'should connect for machine hostname and random ports' {
    export HBASE2__DOCKER_HOSTNAME="$(hostname)"
    echo >&3 "# INFO: export HBASE2__DOCKER_HOSTNAME=$HBASE2__DOCKER_HOSTNAME"
    _docker_compose_up_and_wait

    _hbase_shell 'status'
    _hbase_shell "create 'table', 'f'"
    _hbase_shell "scan 'table'"
}
