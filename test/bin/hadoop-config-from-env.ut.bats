#!/usr/bin/env bats

load 'setup'

@test "should escape underscores accordingly" {
    (
        export SOME_PREFIX_some___underscore=value
        export SOME_PREFIX_some__dash=value
        export SOME_PREFIX_some_dot=value
        export SOME_PREFIX_Capitalized=value
        run bin/hadoop-config-from-env SOME_PREFIX_

        [ "$status" -eq 0 ]
        [[ "$output" = *'<name>some_underscore</name>'* ]]
        [[ "$output" = *'<name>some-dash</name>'* ]]
        [[ "$output" = *'<name>some.dot</name>'* ]]
        [[ "$output" = *'<name>Capitalized</name>'* ]]
    )
}

@test "should build properties file" {
    (
        export SOME_PREFIX_some_dot=value
        run bin/hadoop-config-from-env SOME_PREFIX_ .properties

        [ "$status" -eq 0 ]
        [[ "$output" = *'some.dot=value'* ]]
    )
}
