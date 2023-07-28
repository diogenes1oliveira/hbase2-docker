#!/usr/bin/env bats

load 'setup'

@test "should load environment variables" {
    dotenv='
VAR1=1
 VAR2=0
VAR2=2
VAR3
#VAR1=false
  #VAR1=3
    '

    unset VAR1
    unset VAR2
    unset VAR3

    (
        source ./bin/dotenv-load <(printf '%s' "${dotenv}")
        assert_equal "${VAR1:-}" '1'
        assert_equal "${VAR2:-}" '2'
        assert_equal "${VAR3:-}" ''
    )
}

function echo_with_delay() {
    sleep "$1"
    printf '%s' "$3" > "$2"
}

@test "should wait for env file to show up" {
    env_file="$BATS_TEST_TMPDIR/env"

    unset VAR1
    echo_with_delay 1 "$env_file" 'VAR1=1' &

    (
        source ./bin/dotenv-load --wait=3 "$env_file"
        assert_equal "${VAR1:-}" '1'
    )
}

@test "should echo escaped environment variables" {
    env_file="$BATS_TEST_TMPDIR/env"
    printf '%s\n' $'VAR1=\'some\"\\ $value' > "$env_file"
    echo 'VAR2=2' >> "$env_file"
    echo 'VAR3=' >> "$env_file"

    unset VAR1 VAR2 VAR3
    run --separate-stderr ./bin/dotenv-load --echo "$env_file"
    [ "$status" -eq 0 ]

    [ "${lines[0]}" = "export VAR1=\\'some\\\"\\\\\ \\\$value" ]
    [ "${lines[1]}" = 'export VAR2=2' ]
    [ "${lines[2]}" = "export VAR3=''" ]
}
