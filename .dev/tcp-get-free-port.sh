#!/usr/bin/env bash

set -euo pipefail
SCRIPT="$0"

usage() {
    cat <<eof
Finds a free TCP port

Usage:
    $SCRIPT [PORT_START] [PORT_STOP]

Options:
    PORT_START  port to start scanning from (default: 1024)
    PORT_STOP   port to stop scanning at (default: 32767)
eof
}

PORT_START="${1:-1024}"
PORT_STOP="${2:-32767}"

main() {
    echo >&2 "INFO: looking for free ports in [$PORT_START, $PORT_STOP]"

    for port in $(seq "$PORT_START" "$PORT_STOP"); do
        if nc -z '127.0.0.1' "$port"; then
            continue
        fi

        echo >&2 "INFO: found free port $port"
        printf '%s' "$port"
        if [ -t 1 ]; then
            echo
        fi

        return 0
    done

    echo >&2 "ERROR: no port available"
    return 2
}

for arg; do
    case "$arg" in
    -h | --help )
        usage
        exit 0
        ;;
    esac
done

if ! [[ "$PORT_START" =~ ^[1-9][0-9]+$ ]]; then
    echo >&2 "ERROR: invalid start port"
    exit 1
fi

if ! [[ "$PORT_STOP" =~ ^[1-9][0-9]+$ ]]; then
    echo >&2 "ERROR: invalid stop port"
    exit 1
fi

main
