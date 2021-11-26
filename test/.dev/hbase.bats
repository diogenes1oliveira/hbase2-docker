
setup() {
    load '../utils'
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'

    set_hbase_env
    go_to_repo_root
    export TEMP_TABLE="test-$(uuidgen)"

    make -s kill || true
    OUTPUT=./var/hbase make -s hbase/extract
    export HBASE_PREFIX="$(realpath ./var/hbase)"
}

teardown() {
    make -s kill || true
}

hbase_start_and_wait() {
    make -s start
    do_with_retry -m10 ./bin/hbase-shell-run.sh 'status'
}

@test "HBase Put and Scan work with default ports" {
    hbase_start_and_wait

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
        ./bin/hbase-config-build.sh --no-defaults xml
    )

    (
        export HBASE_CONF_hbase_master_port="20000"
        export HBASE_CONF_hbase_master_info_port="20010"
        export HBASE_CONF_hbase_regionserver_port="20020"
        export HBASE_CONF_hbase_regionserver_info_port="20030"
        export HBASE_CONF_hbase_zookeeper_property_clientPort="20040"

        hbase_start_and_wait
    )

    run ./bin/hbase-shell-run.sh "
        create '${TEMP_TABLE}', 'f'
        put '${TEMP_TABLE}', 'row', 'f:col', 'this value is bananas', (Time.now.to_i * 1000)
    "
    assert_success
    assert_output --partial "Created table ${TEMP_TABLE}"

    run ./bin/hbase-shell-scan.sh "${TEMP_TABLE}"
    assert_success
    assert_output --partial 'this value is bananas'
}
