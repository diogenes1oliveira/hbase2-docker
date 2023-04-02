#!/usr/bin/env bash
# shellcheck disable=SC2001

set -euo pipefail
shopt -s extglob

SCRIPT="$0"

usage() {
    cat <<eof
Extracts the value of a LABEL, ENV or ARG declared in the Dockerfile

Obs: this will NOT handle weird cases, such as when there is a escape inside
the label value, the label name occurs inside another label value, etc...

Usage:
    $SCRIPT TYPE=NAME
eof
}

TYPE=
NAME=

main() {

    prepend=

    # echo >&2 "Searching for $TYPE=($NAME)"

    while read -r line || [[ -n $line ]]; do
        # remove trailing and leading whitespace
        line="${line##*( )}"
        line="${line%%*[[:blank:]]}"

        # skip comments and empty lines
        if [ -z "$line" ] || [[ "$line" == '#'* ]]; then
            continue
        fi

        # prepend keyword of the previous line if set
        if [ -n "$prepend" ]; then
            line="$prepend$line"
            prepend=
        fi

        # skip other commands
        if [[ "$line" =~ ^(ENV|LABEL|ARG)[[:space:]]+(.*)$ ]]; then
            line_type="${BASH_REMATCH[1]}"
            line="${BASH_REMATCH[2]}"
        else
            continue
        fi

        # check continuation backslash
        if [[ "$line" =~ ^(.*?)(\s*\\)$ ]]; then
            prepend="$line_type "
            line="${BASH_REMATCH[1]}"
        fi

        # remove trailing whitespce
        line="${line%%*( )}"

        line_name="${line%%=*}"
        line_value="${line#*=}"

        # no value, just the declaration
        if [ "$line" = "$line_name" ]; then
            continue
        fi

        # echo >&2 "line_type=($line_type) line_name=($line_name) line_value=($line_value)"

        if [ "$TYPE" = "$line_type" ] && [ "$NAME" = "$line_name" ]; then
            printf '%s' "$line_value" | tr -d "\"'"
            if [ -t 1 ]; then
                echo
            fi
            return 0
        fi

    done

    echo >&2 "ERROR: value not found in the Dockerfile"
    return 1
}

for arg; do
    if [[ "$arg" =~ ^-h|--help$ ]]; then
        usage
        exit 0
    fi
done

if [[ "${1:-}" =~ ^(ENV|LABEL|ARG)=(.+) ]]; then
    TYPE="${BASH_REMATCH[1]}"
    NAME="${BASH_REMATCH[2]}"
else
    echo >&2 "invalid query '${1:-}'"
    exit 1
fi

main
