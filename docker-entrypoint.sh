#!/usr/bin/env bash

set -euo pipefail

if [ -n "${HBASE_ENV_FILE:-}" ]; then
    if ! [ -e "$HBASE_ENV_FILE" ]; then
        while ! [ -e "$HBASE_ENV_FILE" ]; do
            echo >&2 "INFO: env file still not present in $HBASE_ENV_FILE, trying again in 5s"
            sleep 5
        done
        # make sure we've written everything in the .env
        sleep 3
    fi

    echo >&2 "INFO: loading environment variables from $HBASE_ENV_FILE"
    # shellcheck disable=SC1091
    source dotenv-load "$HBASE_ENV_FILE"
fi


HBASE_SITE_PATH="${HBASE_CONF_DIR:-}/hbase-site.xml"

if ! [ -e "$HBASE_SITE_PATH" ] && [ -d "${HBASE_CONF_DIR:-}" ]; then
    echo >&2 "INFO: generating hbase-site.xml from environment variables"
    hbase-xml-from-env HBASE_SITE_ > "$HBASE_SITE_PATH"
fi


HBASE_POLICY_PATH="${HBASE_CONF_DIR:-}/hbase-policy.xml"

if ! [ -e "$HBASE_POLICY_PATH" ] && [ -d "${HBASE_CONF_DIR:-}" ]; then
    echo >&2 "INFO: generating hbase-policy.xml from environment variables"
    hbase-xml-from-env HBASE_POLICY_ > "$HBASE_POLICY_PATH"
fi


if [ -d /docker-entrypoint-init.d ]; then
    echo >&2 "INFO: finding initialization scripts"

    while read -r script; do
        echo >&2 "INFO: executing initialization script $script"
        # shellcheck disable=SC1090
        source "$script"
    done < <(find /docker-entrypoint-init.d -mindepth 1 -maxdepth 1 -name '*.sh' | sort )
fi

if [ -n "${HBASE_PORT_MAPPINGS:-}" ]; then
    echo >&2 "INFO: mapping ports $HBASE_PORT_MAPPINGS"
    tcp-map-ports "$HBASE_PORT_MAPPINGS"
fi

if [ -n "${HBASE_RUN_AS:-}" ]; then
    exec runuser -u "$HBASE_RUN_AS" -- "$@"
else
    exec "$@"
fi
