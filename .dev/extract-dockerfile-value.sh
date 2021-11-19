#!/usr/bin/env bash
set -euo pipefail
NAME="$0"

usage() {
    cat <<eof
Extracts the value of a LABEL or ENV declared in a Dockerfile

Obs: this will NOT handle weird cases, such as when there is a escape inside
the label value, the label name occurs inside another label value, etc...

Usage:
    ${NAME} LABEL=<NAME> | ENV=<NAME>
eof
}

TYPE=
NAME=

main() {
    # Merge escaped continuation lines, remove trailing spaces and get
    # just the LABEL instructions
    readarray -t lines < <(
        sed -z 's/\\\n/ /g' | \
        sed -E 's/^\s+//g' | \
        grep "^${TYPE}" | \
        sed 's/$/ /g'
    )

    pattern="${NAME}=([^\\s\"]*|\"[^\"]*\") "

    for line in "${lines[@]+"${lines[@]}"}"; do
        if declaration="$( match_pattern "${pattern}" <<<"${line}" )"; then
            sed -e "s/^${NAME}=//g" -e 's/ $//g' <<<"${declaration}"
            return 0
        fi
    done

    echo >&2 "ERROR: value not found in the Dockerfile"
    return 1
}

match_pattern() {
    pattern="$1"
    grep -ohP "${pattern}" | head -n 1 | tr -d '"'
}

if [[ "${1:-}" =~ ^-h|--help$ ]]; then
    usage
else
    TYPE="$(sed 's/=.*//' <<<"${1:-}")"
    if ! [[ "${TYPE}" =~ ^LABEL|ENV$ ]]; then
        echo >&2 "ERROR: bad spec"
    fi
    NAME="$(sed "s/^${TYPE}=//" <<<"${1:-}")"
    main
fi
