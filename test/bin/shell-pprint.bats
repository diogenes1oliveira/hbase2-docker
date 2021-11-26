
setup() {
    load '../utils'
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'

    go_to_repo_root
}

verify() {
    input="$1"
    expected="$2"

    run ./bin/shell-pprint.sh <<<"${input}"
    assert_success

    value_from_output=$( ./bin/shell-pprint.sh <<<"${input}" )
    value_in_array=( "${value_from_output}" )

    assert_equal "${value_from_output}" "${expected}"
    assert_equal "${value_in_array[0]}" "${expected}"
}

@test "empty string" {
    verify '' "''"
}

@test "alphanumerical string" {
    verify 'abc123' 'abc123'
}

@test "string with \$" {
    verify '$a=b' "\\\$a=b"
}

@test "string with spaces" {
    verify 'a = b ' "\$'a = b '"
}

@test "string with spaces and \$" {
    verify 'a = 123 ' "\$'a = 123 '"
}
