#!/usr/bin/env bash
set -euo pipefail
NAME="$0"

usage() {
    cat <<eof
Rebases links to local files in Markdown so they point to a remote URL

This script will loop through all links in the markdown from the input,
prepending the base remote URL to all of those pointing to local files 
relative to the markdown directory.

Obs: only valid links will be replaced, i.e., the file must exist currently
in the file system.

Usage:
    ${NAME} <BASE_URL> [-i <PATH>] [-o <PATH>]

Options:
    BASE_URL        Base link URL
    -i, --input     path to the Makefile to be considered (default: -)
                    If equals to '-', this script will read the contents from
                    the stdin and consider the current directory as the base
    -o, --output    output path of the result (default: -)
                    If equals to '-', the output will be printed to stdout
eof
}

BASE_URL=
BASE_DIR=
INPUT=-
OUTPUT=-

args_get() {
    getopt -l 'help,input:,output:' -o 'hi:o:' -a -- "$@"
}

main() {
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
    link="${1:-}"
    if ! [[ "${link}" =~ \[[^\]]+\]\(([^\)]+)\) ]]; then
        echo >&2 "ERROR: input is not a Markdown link: '${link}'"
        exit 2
    fi
    printf '%s' "${BASH_REMATCH[1]}"
}

link_is_local() {
    link="${1:-}"
    ( cd "${BASE_DIR}" && test -f "${link}" )
}

path_to_url() {
    path="${1:-}"
    path_relative="$(realpath --relative-to="${BASE_DIR}" "${path}")"

    printf '%s' "${BASE_URL}/$(sed -E 's;^\.?/;;' <<<"${path_relative}")"
}

args_error() {
    local msg="${1:-failed to parse options}"
    usage >&2
    echo >&2
    echo >&2 "ERROR: ${msg}"
    exit 1
}

vars_require() {
    for arg in "$@"; do
        if [ -z "${!arg:-}" ]; then
            args_error "no value for $arg"
        fi
    done
}

arguments_parse() {
    if ! OPTS="$(args_get "$@")"; then
        args_error
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

    BASE_URL="${1:-}"
    BASE_URL="${BASE_URL%/}"

    vars_require BASE_URL INPUT OUTPUT

    if [ "${INPUT}"  = '-' ]; then
        BASE_DIR="$(pwd)"
    else
        BASE_DIR="$(dirname "$(realpath "${INPUT}")")"
    fi
}

arguments_parse "$@"
main
