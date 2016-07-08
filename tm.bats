#!/usr/bin/env bats
#
# Bats test file for tm.sh
# Bats: https://github.com/sstephenson/bats

setup()
{
  TM="./tm.sh"
  export TMRC="tests/tmrc"
  export TM_CMD_PATH="tests/cmd"
  # Use a test server
  export TMUX_ARGS="-L test-$$"
}

teardown()
{
  # Kill test server if it is running
  ${TM} -K || true
}

@test "basic tm.sh -h" {
  run ${TM} -h
  test $status -eq 0 || echo $output 1>&2
  [ "$status" -eq 0 ]
  echo ${lines[0]} | grep -q "Usage"
}

@test "tm.sh unknown cmd failure" {
  run ${TM} xyzzy
  echo $output 1>&2
  [ "$status" -eq 1 ]
  echo ${lines[0]} | grep -q "Unknown command"
}

@test "tm.sh tm-test-check-server" {
  run ${TM} -d tm-test-check-server
  echo $output 1>&2
  [ "$status" -eq 1 ]
}

@test "tm.sh tm-test-new-session" {
  run ${TM} -d tm-test-new-session
  test $status -eq 0 || echo $output 1>&2
  [ "$status" -eq 0 ]
}

@test "tm.sh tm-test-splitting" {
  run ${TM} tm-test-splitting
  test $status -eq 0 || echo $output 1>&2
  [ "$status" -eq 0 ]
}

@test "tm.sh tm-test-multiple-windows" {
  run ${TM} tm-test-multiple-windows
  test $status -eq 0 || echo $output 1>&2
  [ "$status" -eq 0 ]
}

@test "tm.sh tm-test-send" {
  run ${TM} tm-test-send
  test $status -eq 0 || echo $output 1>&2
  [ "$status" -eq 0 ]
}

@test "tm.sh tm-test-session-name" {
  run ${TM} tm-test-session-name
  test $status -eq 0 || echo $output 1>&2
  [ "$status" -eq 0 ]
}
