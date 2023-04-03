#!/usr/bin/env bash

set -euo pipefail

function log_info {
    echo "$(date -u '+%Y-%m-%dT:%H:%M:%S.%NZ') INFO [docker-entrypoint.sh] $*" >&2
}

if [ -n "${HBASE_ENV_FILE:-}" ]; then
    if ! [ -e "$HBASE_ENV_FILE" ]; then
        while ! [ -e "$HBASE_ENV_FILE" ]; do
            log_info "env file still not present in $HBASE_ENV_FILE, trying again in 5s"
            sleep 5
        done
        # make sure we've written everything in the .env
        sleep 3
    fi

    # shellcheck disable=SC1091
    source dotenv-load "$HBASE_ENV_FILE"
    log_info "loaded environment variables from $HBASE_ENV_FILE"
fi


HBASE_SITE_PATH="${HBASE_CONF_DIR:-}/hbase-site.xml"

if ! [ -e "$HBASE_SITE_PATH" ] && [ -d "${HBASE_CONF_DIR:-}" ]; then
    hbase-xml-from-env HBASE_SITE_ > "$HBASE_SITE_PATH"
    log_info "generated hbase-site.xml from environment variables"
fi


HBASE_POLICY_PATH="${HBASE_CONF_DIR:-}/hbase-policy.xml"

if ! [ -e "$HBASE_POLICY_PATH" ] && [ -d "${HBASE_CONF_DIR:-}" ]; then
    hbase-xml-from-env HBASE_POLICY_ > "$HBASE_POLICY_PATH"
    log_info "generated hbase-policy.xml from environment variables"
fi


if [ -d /docker-entrypoint-init.d ]; then
    log_info "finding initialization scripts"

    while read -r script; do
        log_info "executing initialization script $script"
        # shellcheck disable=SC1090
        source "$script"
    done < <(find /docker-entrypoint-init.d -mindepth 1 -maxdepth 1 -name '*.sh' | sort )

    log_info "executed all initialization scripts"
fi

if [ -n "${HBASE_PORT_MAPPINGS:-}" ]; then
    log_info "mapping ports $HBASE_PORT_MAPPINGS"
    tcp-map-ports "$HBASE_PORT_MAPPINGS"
    log_info "all ports mapped"
fi

log_info "will now start HBase"

if [ -n "${HBASE_RUN_AS:-}" ]; then
    exec runuser -u "$HBASE_RUN_AS" -- "$@"
else
    exec "$@"
fi
