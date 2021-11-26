#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$0"

usage() {
    cat <<eof
Pretty prints the input as a shell-escaped output

Usage:
    echo -n 'INPUT' | ${SCRIPT}

The output of this command should be directly assigned to a variable without
escaping. Just don't interpolate it directly inside an array:

- DO: value=\$( ${SCRIPT} <<<'dangerous input' )
      value_in_array=( "\${value}" )
- DON'T: value_in_array=( ${SCRIPT} <<<'dangerous input' )
eof
}

main() {
    input="$(cat)"
    fully_escaped="$(printf '%q' "${input}")"

    if [[ "${fully_escaped}" = *\\\ * ]]; then
        printf '%s' "${fully_escaped}" | quote_spaces
    else
        printf '%s' "${fully_escaped}"
    fi
}

quote_spaces() {
    sed 's/\\ / /g' | sed "s/^/\$'/g" | sed "s/$/'/g"
}

case "${1:-}" in
-h | --help )
    usage
    exit 0 ;;
esac

main
