#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$0"

usage() {
    cat <<eof
Extracts the value of a LABEL or ENV declared in a Dockerfile

Obs: this will NOT handle weird cases, such as when there is a escape inside
the label value, the label name occurs inside another label value, etc...

Usage:
    ${SCRIPT} LABEL=<NAME> | ENV=<NAME>
    LABEL=<NAME> ${SCRIPT}
    ENV=<NAME> ${SCRIPT}
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
    exit 0
elif [[ "${1:-}" =~ ^(ENV|LABEL)=(.+) ]]; then
    TYPE="${BASH_REMATCH[1]}"
    NAME="${BASH_REMATCH[2]}"
elif [ -n "${ENV:-}" ] && [ -z "${LABEL:-}" ]; then
    TYPE=ENV
    NAME="${ENV}"
elif [ -z "${ENV:-}" ] && [ -n "${LABEL:-}" ]; then
    TYPE=LABEL
    NAME="${LABEL}"
else
    echo >&2 "ERROR: exactly one of ENV= or LABEL= must be set"
    exit 1
fi

main
