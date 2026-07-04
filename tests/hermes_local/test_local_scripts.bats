#!/usr/bin/env bats

setup() {
    export HERMES_HOME="${BATS_TMPDIR}/hermes_home"
    export TEST_DIR="${BATS_TMPDIR}/test_hermes"
    mkdir -p "${HERMES_HOME}/logs"
    mkdir -p "${TEST_DIR}"
}

teardown() {
    rm -rf "${HERMES_HOME}"
    rm -rf "${TEST_DIR}"
}

@test "install.sh exists" {
    [ -f ./hermes_local/install.sh ]
}

@test "install.sh has proper shebang" {
    head -1 ./hermes_local/install.sh | grep -q "#!/bin/bash"
}

@test "install.sh syntax is valid" {
    bash -n ./hermes_local/install.sh
}

@test "install.sh has error handling" {
    grep -qE "set -|trap " ./hermes_local/install.sh
}

@test "run.sh exists and is executable" {
    [ -f ./hermes_local/run.sh ]
    [ -x ./hermes_local/run.sh ]
}

@test "run.sh has proper shebang" {
    head -1 ./hermes_local/run.sh | grep -q "#!/bin/bash"
}

@test "run.sh syntax is valid" {
    bash -n ./hermes_local/run.sh
}

@test "run.sh has start|stop|status commands documented" {
    grep -q "start\|stop\|status" ./hermes_local/run.sh
}

@test "test.sh exists and is executable" {
    [ -f ./hermes_local/test.sh ]
    [ -x ./hermes_local/test.sh ]
}

@test "test.sh has proper shebang" {
    head -1 ./hermes_local/test.sh | grep -q "#!/bin/bash"
}

@test "test.sh syntax is valid" {
    bash -n ./hermes_local/test.sh
}

@test "test.sh supports --quick flag" {
    grep -q "\-\-quick" ./hermes_local/test.sh
}

@test "test.sh supports --list flag" {
    grep -q "\-\-list" ./hermes_local/test.sh
}

@test "setup-tools.sh exists" {
    [ -f ./hermes_local/setup-tools.sh ]
}

@test "setup-tools.sh syntax is valid" {
    bash -n ./hermes_local/setup-tools.sh
}

@test "setup-tools.sh checks for required tools" {
    grep -qE "shellcheck|yamllint|ruff|pre-commit" ./hermes_local/setup-tools.sh
}

@test "init.sh exists" {
    [ -f ./hermes_configs/init.sh ]
}

@test "init.sh syntax is valid" {
    bash -n ./hermes_configs/init.sh
}

@test "playwright-start.sh exists" {
    [ -f ./hermes_configs/playwright-start.sh ]
}

@test "playwright-start.sh syntax is valid" {
    bash -n ./hermes_configs/playwright-start.sh
}

@test "precommit.sh exists and is executable" {
    [ -f ./precommit.sh ]
    [ -x ./precommit.sh ]
}

@test "precommit.sh syntax is valid" {
    bash -n ./precommit.sh
}
