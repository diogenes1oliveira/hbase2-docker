#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$0"

usage() {
    cat <<eof
Extracts the value of a LABEL, ENV or ARG declared in the Dockerfile

Obs: this will NOT handle weird cases, such as when there is a escape inside
the label value, the label name occurs inside another label value, etc...

Usage:
    $SCRIPT LABEL=l | ENV=e | ARG=a
    LABEL=l $SCRIPT
    ENV=e $SCRIPT
    ARG=a $SCRIPT
eof
}

TYPE=
NAME=

main() {
    # Delete comments, merge escaped continuation lines, remove trailing spaces
    # and get just the LABEL instructions
    readarray -t lines < <(
        < ./Dockerfile grep -v '^\s*#' | \
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
fi

if [[ "${1:-}" =~ ^(ENV|LABEL|ARG)=(.+) ]]; then
    TYPE="${BASH_REMATCH[1]}"
    NAME="${BASH_REMATCH[2]}"
else
    count=0
    TYPE=

    for t in ENV LABEL ARG; do
        NAME="${!t:-}"
        if [ -n "$NAME" ]; then
            TYPE="$t"
            count="$(( count + 1 ))"
        fi
    done

    if [ "$count" -ne 1 ]; then
        echo >&2 "ERROR: exactly one of ENV= or LABEL= or ARG= must be set"
        exit 1
    fi
fi

main
