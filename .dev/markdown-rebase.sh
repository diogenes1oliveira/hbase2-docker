#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$0"

usage() {
    cat <<eof
Rebases links to local files in Markdown so they point to a remote URL

This script will loop through all links in the markdown from the input,
prepending the base remote URL to all of those pointing to local files 
relative to the markdown directory.

Obs: only valid links will be replaced, i.e., the file must exist currently
in the file system.

Usage:
    ${SCRIPT} <REMOTE> [-i|--input INPUT] [-o|--output OUTPUT]

Options:
    \$REMOTE    Base link URL
    \$INPUT     path to the Makefile to be considered (default: -)
                If equals to '-', this script will read the contents from
                the stdin and consider the current directory as the base
    \$OUTPUT    output path of the result (default: -)
                If equals to '-', the output will be printed to stdout
eof
}

REMOTE="${REMOTE:-}"
INPUT="${INPUT:--}"
OUTPUT="${OUTPUT:--}"
BASE_DIR=

args_get() {
    getopt -l 'help,input:,output:' -o 'hi:o:' -a -- "$@"
}

main() {
    args_parse "$@"
    readarray -t lines < <( input_read )

    for line in "${lines[@]+"${lines[@]}"}"; do
        readarray -t links < <(links_get "${line}")

        for link in "${links[@]+"${links[@]}"}"; do
            url="$(link_get_url "${link}")"

            if link_is_local "${url}"; then
                url_rebased="$(path_to_url "${url}")"
                line="${line//${url}/${url_rebased}}"
            fi
        done

        printf '%s\n' "${line}"

    done > >( output_write )
}

input_read() {
    if [ "${INPUT}"  = '-' ]; then
        cat
    else
        cat "${INPUT}"
    fi
}

output_write() {
    if [ "${OUTPUT}"  = '-' ]; then
        cat
    else
        cat > "${OUTPUT}"
    fi
}

links_get() {
    content="$1"
    grep -ohP '\[[^\]]+\]\([^\)]+\)' <<<"${content}" | sort -u
}

link_get_url() {
    link="$1"
    if ! [[ "${link}" =~ \[[^\]]+\]\(([^\)]+)\) ]]; then
        echo >&2 "ERROR: input is not a Markdown link: '${link}'"
        exit 2
    fi
    printf '%s' "${BASH_REMATCH[1]}"
}

link_is_local() {
    link="$1"
    ( cd "${BASE_DIR}" && test -f "${link}" )
}

path_to_url() {
    path="$1"
    path_relative="$(realpath --relative-to="${BASE_DIR}" "${path}")"
    path_unprefixed="$(sed -E 's;^\.?/;;' <<<"${path_relative}")"

    printf '%s' "${REMOTE}/${path_unprefixed}"
}

args_error() {
    msg="$1"

    usage >&2
    echo >&2
    echo >&2 "ERROR: ${msg}"
    exit 1
}

args_parse() {
    if ! OPTS="$(getopt -l 'help,input:,output:' -o 'hi:o:' -a -- "$@")"; then
        args_error 'failed to parse options'
    fi

    eval set -- "${OPTS}"

    while true; do
        case "$1" in
        -h | --help )
            usage
            exit 0
            ;;
        -i | --input )
            INPUT="${2:-}"
            shift 2
            ;;
        -o | --output )
            OUTPUT="${2:-}"
            shift 2
            ;;
        -- )
            shift
            break
            ;;
        * )
            args_error "Unknown argument '${arg}'"
            ;;
        esac
    done

    REMOTE="${1:-${REMOTE:-}}"
    REMOTE="${REMOTE%/}"

    for var in REMOTE INPUT OUTPUT; do
        if [ -z "${!var:-}" ]; then
            args_error "no value for ${arg}"
        fi
    done

    if [ "${INPUT}" = '-' ]; then
        BASE_DIR="$(pwd)"
    else
        BASE_DIR="$(dirname "$(realpath "${INPUT}")")"
    fi
}

main "$@"
