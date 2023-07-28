#!/usr/bin/env bash

set -euo pipefail

# Initialization script that reads environment variable overrides from $HBASE_ENV_FILE.
# If $HBASE_ENV_FILE_WAIT is set, it will also wait for this number of seconds for the .env file to show up.
#
# This waiting behavior is useful when some configurations are only available once the container starts up, like
# external port numbers

if [ -n "${HBASE_ENV_FILE:-}" ]; then
    eval "$(dotenv-load --wait="${HBASE_ENV_FILE_WAIT:-10}" --echo "$HBASE_ENV_FILE")" 
fi
