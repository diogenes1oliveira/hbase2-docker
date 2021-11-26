
setup() {
    load '../utils'
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'

    go_to_repo_root
}

function verify {
    input="$1"
    expected="$2"

    run ./.dev/markdown-rebase.sh http://localhost <<<"${input}"
    assert_success

    actual="$( ./.dev/markdown-rebase.sh http://localhost <<<"${input}" )"
    assert_equal "${actual}" "${expected}"
}

@test "replaces links" {
    cd "${BATS_TEST_TMPDIR:-}"
    touch some-file

    verify '
        line without links
        [link1](no-such-file) something else [link2](some-file)
   
             # blank [link1](https://example.com)

    ' '
        line without links
        [link1](no-such-file) something else [link2](http://localhost/some-file)
   
             # blank [link1](https://example.com)

    '
}

@test "works with empty inputs" {
    verify '' ''
}
