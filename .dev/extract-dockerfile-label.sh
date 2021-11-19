#!/usr/bin/env bash
set -euo pipefail
NAME="$0"

usage() {
    cat <<eof
Extracts the value of a LABEL declared in a Dockerfile

Obs: this will NOT handle weird cases, such as when there is a escape inside
the label value, the label name occurs inside another label value, etc...

Usage:
    ${NAME} <LABEL>
eof
}

LABEL=

main() {
    # Merge escaped continuation lines, remove trailing spaces and get
    # just the LABEL instructions
    readarray -t lines < <(
        sed -z 's/\\\n/ /g' | \
        sed -E 's/^\s+//g' | \
        grep '^LABEL' | \
        sed 's/$/ /g'
    )

    pattern="${LABEL}=([^\\s\"]*|\"[^\"]*\") "

    for line in "${lines[@]+"${lines[@]}"}"; do
        if declaration="$( match_pattern "${pattern}" <<<"${line}" )"; then
            sed -e "s/^${LABEL}=//g" -e 's/ $//g' <<<"${declaration}"
            return 0
        fi
    done

    echo >&2 "ERROR: label not found in the Dockerfile"
    return 1
}

match_pattern() {
    pattern="$1"
    grep -ohP "${pattern}" | head -n 1 | tr -d '"'
}

if [[ "${1:-}" =~ ^-h|--help$ ]]; then
    usage
else
    LABEL="${1:-}"
    if [ -z "${LABEL}" ]; then
        echo >&2 "ERROR: no label was specified"
    fi
    main "${LABEL}"
fi
