#!/usr/bin/env bats

load 'setup'

_verify_markdown() {
    input="$1"
    expected="$2"

    run .dev/markdown-rebase.sh http://localhost <<<"${input}"
    assert_success

    actual="$( .dev/markdown-rebase.sh http://localhost <<<"${input}" )"
    assert_equal "${actual}" "${expected}"
}

@test "replaces links" {
    _verify_markdown '
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
    _verify_markdown '' ''
}
