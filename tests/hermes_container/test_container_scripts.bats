#!/usr/bin/env bats

setup() {
    export HERMES_HOME="${BATS_TMPDIR}/hermes_home"
    mkdir -p "${HERMES_HOME}/logs"
    mkdir -p "${BATS_TMPDIR}/workspace"
}

teardown() {
    rm -rf "${HERMES_HOME}"
}

@test "start.sh exists and is executable" {
    [ -f ./hermes_container/start.sh ]
    [ -x ./hermes_container/start.sh ]
}

@test "start.sh has proper shebang" {
    head -1 ./hermes_container/start.sh | grep -q "#!/bin/bash"
}

@test "start.sh syntax is valid" {
    bash -n ./hermes_container/start.sh
}

@test "start.sh has error handling or set options" {
    grep -qE "set -|trap " ./hermes_container/start.sh
}

@test "build.sh exists and is executable" {
    [ -f ./hermes_container/build.sh ]
    [ -x ./hermes_container/build.sh ]
}

@test "build.sh has proper shebang" {
    head -1 ./hermes_container/build.sh | grep -q "#!/bin/bash"
}

@test "build.sh syntax is valid" {
    bash -n ./hermes_container/build.sh
}

@test "up.sh exists and is executable" {
    [ -f ./hermes_container/up.sh ]
    [ -x ./hermes_container/up.sh ]
}

@test "up.sh syntax is valid" {
    bash -n ./hermes_container/up.sh
}

@test "down.sh exists and is executable" {
    [ -f ./hermes_container/down.sh ]
    [ -x ./hermes_container/down.sh ]
}

@test "down.sh syntax is valid" {
    bash -n ./hermes_container/down.sh
}

@test "logs.sh exists and is executable" {
    [ -f ./hermes_container/logs.sh ]
    [ -x ./hermes_container/logs.sh ]
}

@test "logs.sh syntax is valid" {
    bash -n ./hermes_container/logs.sh
}

@test "setup-hermes-service.sh exists" {
    [ -f ./hermes_container/setup-hermes-service.sh ]
}

@test "setup-hermes-service.sh syntax is valid" {
    bash -n ./hermes_container/setup-hermes-service.sh
}

@test "apply-last-config.sh exists" {
    [ -f ./hermes_container/apply-last-config.sh ]
}

@test "apply-last-config.sh syntax is valid" {
    bash -n ./hermes_container/apply-last-config.sh
}
