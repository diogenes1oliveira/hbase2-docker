
setup() {
    load '../utils'
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'

    go_to_repo_root
    SCRIPT="$(realpath ./.dev/markdown-rebase.sh)"
}

function verify_markdown {
    input="$1"
    expected="$2"

    run "${SCRIPT}" http://localhost <<<"${input}"
    assert_success

    actual="$( "${SCRIPT}" http://localhost <<<"${input}" )"
    assert_equal "${actual}" "${expected}"
}

@test "replaces links" {
    verify_markdown '
        line without links
        [link1](no-such-file) something else [link2](README.md)
   
             # blank [link1](https://example.com)

    ' '
        line without links
        [link1](no-such-file) something else [link2](http://localhost/README.md)
   
             # blank [link1](https://example.com)

    '
}

@test "works with empty inputs" {
    verify_markdown '' ''
}
