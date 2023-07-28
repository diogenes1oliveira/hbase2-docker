#!/usr/bin/env bash

bats_require_minimum_version 1.5.0

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'

setup_file() {
    cd "$BATS_TEST_DIRNAME/../.."
}
