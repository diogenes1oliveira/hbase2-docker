#!/usr/bin/env bash

set -euo pipefail

VERSION="$(.dev/maven-get-version.sh)"

if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -n 'true'
else
    echo -n 'false'
fi

if [ -t 1 ]; then
    echo
fi
