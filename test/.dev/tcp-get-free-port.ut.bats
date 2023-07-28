#!/usr/bin/env bats

load 'setup'

@test "validates min port" {
    run .dev/tcp-get-free-port.sh bad-port
    assert_failure

    assert_output --partial 'invalid'
}

@test "validates max port" {
    run .dev/tcp-get-free-port.sh 1025 bad-port
    assert_failure

    assert_output --partial 'invalid'
}

@test "gets a free port" {
    run --separate-stderr .dev/tcp-get-free-port.sh
    assert_success

    local returned_port="$output"
    ! nc -z '127.0.0.1' "$returned_port"
}

@test "fails if no free port in range" {
    local some_port="$(.dev/tcp-get-free-port.sh)"
    nc -l "$some_port" &

    run --separate-stderr .dev/tcp-get-free-port.sh "$some_port" "$some_port"
    assert_failure
}

@test "finds free port in range" {
    local some_port="$(.dev/tcp-get-free-port.sh)"

    run --separate-stderr .dev/tcp-get-free-port.sh "$((some_port-1))" "$((some_port+1))"
    assert_success

    local returned_port="$output"
    [ "$returned_port" = "$some_port" ] || [ "$returned_port" = "$((some_port-1))" ]
}
