#!/usr/bin/env bats
#
# Bats test file for tm.sh
# Bats: https://github.com/sstephenson/bats

setup()
{
  TM="./tm.sh"
  export TMRC="tests/tmrc"
  export TM_CMD_PATH="tests/cmd"

  # Kill tm-testing session if running
  tmux list-sessions -F "#S" | grep -q -x tm-testing && \
    tmux kill-session -t tm-testing || true
}

teardown()
{
  # Kill tm-testing session if running
  tmux list-sessions -F "#S" | grep -q -x tm-testing && \
    tmux kill-session -t tm-testing || true
}

@test "basic tm.sh -h" {
  run ${TM} -h
  [ "$status" -eq 0 ]
  echo ${lines[0]} | grep -q "Usage"
}

@test "tm.sh unknown cmd failure" {
  run ${TM} xyzzy
  [ "$status" -eq 1 ]
  echo ${lines[0]} | grep -q "Unknown command"
}

@test "tm.sh tm-test-new-session" {
  run ${TM} tm-test-new-session
  [ "$status" -eq 0 ]
}

@test "tm.sh tm-test-splitting" {
  run ${TM} tm-test-splitting
  [ "$status" -eq 0 ]
}

@test "tm.sh tm-test-multiple-windows" {
  run ${TM} tm-test-multiple-windows
  [ "$status" -eq 0 ]
}

@test "tm.sh tm-test-send" {
  run ${TM} tm-test-send
  [ "$status" -eq 0 ]
}

@test "tm.sh tm-test-session-name" {
  run ${TM} tm-test-session-name
  [ "$status" -eq 0 ]
}
