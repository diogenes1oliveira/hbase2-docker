#!/usr/bin/env bash

set -euo pipefail

if [ "$(pwd)" = '/' ]; then
    echo >&2 "ERROR: root folder"
    exit 1
fi

mkdir -p ./var/
rm -rf ./var/hbase/

export DOCKER_MODE=-i
export DOCKER_RUN_OPTS='-w /opt'

.dev/docker-run.sh tar -ch --dereference hbase/ | tar -x -C ./var/
