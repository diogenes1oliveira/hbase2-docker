
setup() {
    load 'utils'
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    docker_build
    hbase_extract
}

teardown() {
    docker_cleanup
}

@test "HBase Put and Scan work with default ports" {
    local table="test-$(uuidgen)"
    hbase_start

    do_retry 10 hbase_shell 'status'

    run hbase_shell "
        create '${table}', 'f'
        put '${table}', 'row', 'f:col', 'this value is bananas', (Time.now.to_i * 1000)
    "
    assert_success
    assert_output --partial "Created table ${table}"

    run hbase_scan "${table}"
    assert_success
    assert_output --partial 'this value is bananas'
}

@test "HBase Put and Scan work with non-default ports" {
    local table="test-$(uuidgen)"
    export HBASE_CONF_hbase_master_port="20000"
    export HBASE_CONF_hbase_master_info_port="20010"
    export HBASE_CONF_hbase_regionserver_port="20020"
    export HBASE_CONF_hbase_regionserver_info_port="20030"
    export HBASE_CONF_hbase_zookeeper_property_clientPort="20040"

    hbase_start

    local bkp="$(cat ./var/hbase/conf/hbase-site.xml)"
    cat > ./var/hbase/conf/hbase-site.xml <<eof
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>hbase.zookeeper.quorum</name>
    <value>localhost:20040</value>
  </property>
</configuration>
eof
    do_retry 10 hbase_shell 'status'

    run hbase_shell "
        create '${table}', 'f'
        put '${table}', 'row', 'f:col', 'this value is bananas', (Time.now.to_i * 1000)
    "
    assert_success
    assert_output --partial "Created table ${table}"

    run hbase_scan "${table}"
    assert_success
    assert_output --partial 'this value is bananas'
}
