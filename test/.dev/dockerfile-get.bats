
setup() {
    load '../utils'
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'

    go_to_repo_root
}

@test "works unquoted" {
    run ./.dev/dockerfile-get.sh ENV=person <<<'ENV person=myself'

    assert_success
    assert_output "myself"
}

@test "works quoted" {
    run ./.dev/dockerfile-get.sh LABEL=maintainer <<<'
    LABEL foo=bar \
        maintainer="someone else"'

    assert_success
    assert_output "someone else"
}

@test "works with environment variables" {
    export ENV=
    export LABEL=maintainer
    run ./.dev/dockerfile-get.sh <<<'
    LABEL foo=bar \
        maintainer="someone else"'

    assert_success
    assert_output "someone else"
}

@test "fails when not found" {
    run ./.dev/dockerfile-get.sh LABEL=maintainer <<<'LABEL foo=bar'

    assert_failure
}
