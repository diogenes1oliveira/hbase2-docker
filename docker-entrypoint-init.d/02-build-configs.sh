#!/usr/bin/env bash

set -euo pipefail

# Initialization script that builds the hbase-site.xml and hbase-policy.xml from 
# the environment variables HBASE_SITE_* and HBASE_POLICY_*

export HBASE_CONF_DIR="${HBASE_CONF_DIR:-/etc/hbase}"

if [ -d "${HBASE_CONF_DIR:-}" ]; then
    if ! [ -e "$HBASE_CONF_DIR/hbase-site.xml" ]; then
        hadoop-config-from-env HBASE_SITE_ > "$HBASE_CONF_DIR/hbase-site.xml"
        hadoop-config-from-env HBASE_SITE_ .properties > "$HBASE_CONF_DIR/hbase-site.properties"
        echo >&2 "INFO: generated hbase-site.xml from environment variables"
    fi

    if ! [ -e "$HBASE_CONF_DIR/hbase-policy.xml" ]; then
        hadoop-config-from-env HBASE_POLICY_ > "$HBASE_CONF_DIR/hbase-policy.xml"
        echo >&2 "INFO: generated hbase-policy.xml from environment variables"
    fi
else
    echo >&2 "ERROR: hbase configuration directory $HBASE_CONF_DIR doesn't exist"
    exit 1
fi
