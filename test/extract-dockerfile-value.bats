
setup() {
    load 'utils'
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'

    SCRIPT="$(find_in_hierarchy .dev/extract-dockerfile-value.sh)"
}

@test "works unquoted" {
    run "${SCRIPT}" ENV=person <<<'ENV person=myself'

    assert_success
    assert_output "myself"
}

@test "works quoted" {
    run "${SCRIPT}" LABEL=maintainer <<<'
    LABEL foo=bar \
        maintainer="someone else"'

    assert_success
    assert_output "someone else"
}

@test "fails when not found" {
    run "${SCRIPT}" LABEL=maintainer <<<'LABEL foo=bar'

    assert_failure
}
