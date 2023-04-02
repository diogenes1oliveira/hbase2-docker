
setup() {
    load '../utils'
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'

    go_to_repo_root
}

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
        source ./bin/dotenv-load <( printf '%s' "${dotenv}" )
        assert_equal "${VAR1:-}" '1'
        assert_equal "${VAR2:-}" '2'
        assert_equal "${VAR3:-}" ''
    )
}
