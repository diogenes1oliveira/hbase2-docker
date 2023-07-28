#!/usr/bin/env bats

setup() {
    load '../utils'
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'

    cd "$BATS_TEST_DIRNAME/../.."
}

@test 'stable versions' {
    run .dev/version-is-stable.sh '1.0.0'
    [ "$output" = 'true' ]

    run .dev/version-is-stable.sh '32.1.20'
    [ "$output" = 'true' ]

    run .dev/version-is-stable.sh '0.1.0'
    [ "$output" = 'true' ]
}

@test 'unstable versions' {
    run .dev/version-is-stable.sh '1.0.0-SNAPSHOT'
    [ "$output" = 'false' ]

    run .dev/version-is-stable.sh '32.1.20-SNAPSHOT'
    [ "$output" = 'false' ]

    run .dev/version-is-stable.sh '0.1.0-SNAPSHOT'
    [ "$output" = 'false' ]
}
