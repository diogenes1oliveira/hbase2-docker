#!/bin/sh
set -eu

version="$(grep -F '<version>' pom.xml | tr -d '[:space:]' | tr '<>/' '|' | cut -d'|' -f 3)"
if [ -z "$version" ]; then
    echo >&2 "ERROR: no version available"
    exit 1
fi

if [ -t 1 ]; then
    printf '%s\n' "$version"
else
    printf '%s' "$version"
fi
