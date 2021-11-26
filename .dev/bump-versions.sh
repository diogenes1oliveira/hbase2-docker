#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$0"

usage() {
    cat <<eof
Bumps the version throughout this repository

Obs: this will NOT handle weird cases, such as when there is a escape inside
the label value, the label name occurs inside another label value, etc...

Usage:
    ${SCRIPT} NEW_VERSION
eof
}
