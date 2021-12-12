
setup() {
    load '../utils'
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'

    set_hbase_env
    go_to_repo_root
    export TEMP_TABLE="test-$(uuidgen)"

    teardown
    OUTPUT=./var/hbase make -s hbase/extract
    export HBASE_HOME="$(realpath ./var/hbase)"
}

teardown() {
    make -s kill || true
    make -s compose/rm || true
}

@test "HBase Put and Scan work with default ports" {
    make -s start
    do_with_retry -m10 ./bin/hbase-shell-run.sh 'status'

    run ./bin/hbase-shell-run.sh -l "
        create '${TEMP_TABLE}', 'f'
        put '${TEMP_TABLE}', 'row', 'f:col', 'this value is bananas', (Time.now.to_i * 1000)
    "
    assert_success
    assert_output --partial "Created table ${TEMP_TABLE}"

    run ./bin/hbase-shell-scan.sh "${TEMP_TABLE}"
    assert_success
    assert_output --partial 'this value is bananas'

}

@test "HBase Put and Scan work with non-default ports from outside the container" {
    # Working in the local filesystem. Let's set just the ZooKeeper port, because
    # the others ones should be automatically detected
    (
        export HBASE_CONF_hbase_zookeeper_property_clientPort="20040"
        export HBASE_CONF_DIR="${HBASE_HOME}/conf"
        ./bin/hbase-config-build.sh --no-defaults xml
    )

    return 0
    (
        export HBASE_CONF_hbase_master_port="20000"
        export HBASE_CONF_hbase_master_info_port="20010"
        export HBASE_CONF_hbase_regionserver_port="20020"
        export HBASE_CONF_hbase_regionserver_info_port="20030"
        export HBASE_CONF_hbase_zookeeper_property_clientPort="20040"

        make -s start
    )

    do_with_retry -m10 ./bin/hbase-shell-run.sh 'status'

    run ./bin/hbase-shell-run.sh "
        create '${TEMP_TABLE}', 'f'
        put '${TEMP_TABLE}', 'row', 'f:col', 'this value is apples', (Time.now.to_i * 1000)
    "
    assert_success
    assert_output --partial "Created table ${TEMP_TABLE}"

    run ./bin/hbase-shell-scan.sh "${TEMP_TABLE}"
    assert_success
    assert_output --partial 'this value is apples'
}

@test "HBase Put and Scan work in cluster mode" {
    make compose/up
    do_with_retry -m10 ./bin/hbase-shell-run.sh 'status'

    run ./bin/hbase-shell-run.sh -l "
        create '${TEMP_TABLE}', 'f'
        put '${TEMP_TABLE}', 'row', 'f:col', 'this value is oranges', (Time.now.to_i * 1000)
    "
    assert_success
    assert_output --partial "Created table ${TEMP_TABLE}"

    run ./bin/hbase-shell-scan.sh "${TEMP_TABLE}"
    assert_success
    assert_output --partial 'this value is oranges'

}
