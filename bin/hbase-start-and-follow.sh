#!/usr/bin/env bash

/opt/hbase-current/bin/start-hbase.sh "$@" && exec tail -f /opt/hbase-current/logs/*
