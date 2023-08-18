#!/usr/bin/env bats

load 'setup'

@test "should replace underscores accordingly" {
    (
        export SOME_PREFIX_SOME__DASH=value
        export SOME_PREFIX_SOME_DOT=value
        export SOME_PREFIX_aLtErNaTe=value
        run bin/hadoop-config-from-env SOME_PREFIX_

        [ "$status" -eq 0 ]
        [[ "$output" = *'<name>some-dash</name>'* ]]
        [[ "$output" = *'<name>some.dot</name>'* ]]
        [[ "$output" = *'<name>alternate</name>'* ]]
    )
}

@test "should use triple underscores as escapes" {
    (
        export SOME_PREFIX_TRIPLE___UNDERSCORE____ESCAPES=value

        run bin/hadoop-config-from-env SOME_PREFIX_

        [ "$status" -eq 0 ]
        [[ "$output" = *'<name>tripleUnderscore_escapes</name>'* ]]
    )
}

@test "should build properties file" {
    (
        export SOME_PREFIX_SOME_DOT=value
        run bin/hadoop-config-from-env SOME_PREFIX_ .properties

        [ "$status" -eq 0 ]
        [[ "$output" = *'some.dot=value'* ]]
    )
}
