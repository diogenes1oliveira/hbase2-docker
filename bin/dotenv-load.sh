#!/usr/bin/env bash

set -euo pipefail

SCRIPT="${BASH_SOURCE[0]:-$0}"

usage() {
    cat <<EOF
Loads environment variables from a .env file

Usage:
    $SCRIPT ENV_FILE

Options:
    ENV_FILE    path to the .env file. Will wait for it to show up if not existing

Obs:
- Lines beginning with '#' are ignored
- Only single-lined variables are supported
EOF
}

main() {
    args_parse "$@"


    if ! [ -e "${ENV_FILE}" ]; then
        while ! [ -e "${ENV_FILE}" ]; do
            info ".env file ${ENV_FILE} not found, waiting for 3s"
            sleep 3
        done
        sleep 3
    fi

    while read -r line; do
        if [[ "${line}" =~ ^([a-zA-Z0-9_]+)=(.*)$ ]]; then
            name="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            export "${name}=${value}"
        fi
    done < <( env_get_lines )
}

env_get_lines() {
    < "${ENV_FILE}" sed -e '/^\s\+$/d' | sed -e '/^\s*#.*/d'
}

args_parse() {
    case "${1:-}" in
    -h | --help )
        usage && exit 0 ;;
    esac
    
    ENV_FILE="${1:-}"

    if [ -z "${ENV_FILE}" ]; then
        usage >&2
        echo >&2 ""
        echo >&2 "ERROR: no ENV_FILE specified"
        return 1
    fi
}

main "$@"
