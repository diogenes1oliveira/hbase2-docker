
setup() {
    load 'utils'
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'

    SCRIPT="$(find_in_hierarchy .dev/rebase-markdown-links.sh)"
}

function verify_output {
    input="$1"
    expected="$2"

    run "${SCRIPT}" http://localhost <<<"${input}"
    assert_success

    actual="$("${SCRIPT}" http://localhost <<<"${input}")"
    assert_equal "${actual}" "${expected}"
}

@test "replaces links" {
    cd "${BATS_TEST_TMPDIR:-}"
    touch some-file

    verify_output '
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
    verify_output '' ''
}
