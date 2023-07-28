#!/usr/bin/env bats

load 'setup'

@test "works unquoted" {
    run .dev/dockerfile-get.sh ENV=person <<<'ENV person=myself'

    assert_success
    assert_output "myself"
}

@test "works quoted" {
    run .dev/dockerfile-get.sh LABEL=maintainer <<<'
    LABEL foo=bar \
        maintainer="someone else"'

    assert_success
    assert_output "someone else"
}

@test "fails when not found" {
    run .dev/dockerfile-get.sh LABEL=maintainer <<<'LABEL foo=bar'

    assert_failure
}
