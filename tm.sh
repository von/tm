#!/bin/bash
#
# tm: Create new tmux sessions or windows

TM_VERSION="0.12.0"

TMRC=${TMRC:-${HOME}/.tmux/tmrc}
TM_CMD_PATH=${TM_CMD_PATH:-${HOME}/.tmux/tm}
TM_DEFAULT_CMD="default"

# Session and window name to use if starting tmux server
TM_START_WINDOW_NAME=${TM_START_WINDOW_NAME:-tm-window}
TM_START_SESSION_NAME=${TM_START_SESSION_NAME:-tm-session}

# These can be overridden by ~/.tmux/tmrc
TMUX_CMD=${TMUX_CMD:-"tmux"}
TMUX_ARGS=${TMUX_ARGS:-""}

######################################################################
#
# Source command file
# Usage: tm_cmd [-D] <filename>
#   -D  Don't check for runnig sever
tm_cmd()
{
  local _check_server="1"
  test ${1} = "-D" && { shift ; _check_server="0" ; }
  local _cmd=${1}
  case ${_cmd} in
    */*|/*)  # Path to file
      test -r "${_cmd}" || \
        { echo "No such file: \"${_cmd}\"" ; return 1 ; }
      # Tmux needs full path
      local _cmd_file="$(cd "$(dirname "$_cmd")"; pwd)/$(basename "$_cmd")"
      test -r "${_cmd_file}" || \
        { echo "No such file: \"${_cmd_file}\"" ; return 1 ; }
      ;;
    *)
      local _cmd_file=${TM_CMD_PATH}/${_cmd}
      test -r "${_cmd_file}" || \
        { echo "Unknown command \"${_cmd}\"" ; return 1 ; }
      ;;
  esac

  if test ${_check_server} -eq 1 ; then
    tm_check_server || tm_start_server "${_cmd}"
  fi
  tm_process_cmd_file "${_cmd_file}"
}

# Process a command file
# Usage: tm_process_cmd_file <filename>
# Handles "@tm-if-not: <tmux command>" directive
tm_process_cmd_file()
{
  local _cmd_file="${1}"
  local _tmux_cmd=$(sed -n "s/^#@tm-if-not: \(.*\)$/\1/p" ${_cmd_file})
  if test -n "${_tmux_cmd}" ; then
    if ${TMUX_CMD} ${TMUX_ARGS} ${_tmux_cmd} >& /dev/null ; then
      return 0
    fi
  fi
  ${TMUX_CMD} ${TMUX_ARGS} source-file ${_cmd_file}
}

# Return 0 if server already running, else 1
# Usage: tm_check_server
tm_check_server()
{
  if ${TMUX_CMD} ${TMUX_ARGS} ls >/dev/null 2>&1 ; then
    return 0
  fi
  return 1
}

# Start the tmux server
# Usage: tm_start_server [<first_command>]
# Uses the tm-start-server command, which must start a session
tm_start_server()
{
  tm_check_server && { echo "Attempt to start already running server." >&2 ; return 1 ; }
  ${TMUX_CMD} ${TMUX_ARGS} new-session -d \
    -n ${TM_START_WINDOW_NAME} -s ${TM_START_SESSION_NAME}
  tm_check_server || { echo "${TM_START_SERVER_CMD} failed to start server." >&2 ; return 1 ; }
  }

######################################################################
#
# Top-level commands
#

cmd_help()
{
  cat <<EOF
  Usage: $0 [<options>] [<session name>]

  Options:
  -h       Print help and exit.
  -i       If attaching, attach independantly.
  -I       If attaching, do not attach independantly.
  -k       Kill <session name>.
  -K       Kill tmux server.
  -l       List running sessions.
  -ls      List available sessions. Meant for use by completion code.
  -v       Verbose, turn on logging in tmux.
  -V       Print version and exit.

  With no option to contrary, create or attach to <session name>.
EOF
}

# List running sessions
cmd_list()
{
  ${TMUX_CMD} ${TMUX_ARGS} -q list-sessions 2> /dev/null | cut -f 1 -d ':'
}

# List sessions we have configuration files for
cmd_ls()
{
  (test -d ${TM_CMD_PATH} && cd ${TM_CMD_PATH} && ls -1 ) | \
    grep -v -e "~$" | grep -v -e "^#.*#$" | sort | uniq
}

cmd_kill()
{
  tm_kill_session "${1}"
}

cmd_kill_server()
{
  ${TMUX_CMD} ${TMUX_ARGS} kill-server >& /dev/null
}

cmd_start_server()
{
  tm_start_server
}

cmd_cmd()
{
  tm_cmd "${@}"
}

######################################################################
#
# Main

set -e  # Exit on error

# Command
cmd="cmd"

debug="false"
verbose="false"

while true; do
  case ${1:-""} in
    -d)
      echo "Debug mode activated."
      debug="true"
      shift
      ;;
    -h)
      cmd_help
      exit 0
      ;;
    -l)  # List running sessions
      cmd="list"
      shift
      ;;
    -ls)  # List commands we have configuration files for
      cmd="ls"
      shift
      ;;
    -k)
      cmd="kill"
      shift
      ;;
    -K)
      cmd="kill-server"
      shift
      ;;
    -S)
      cmd="start-server"
      shift
      ;;
    -v)
      verbose="true"
      TMUX_ARGS+=" -v"
      shift
      ;;
    -V)
      echo "tm ${TM_VERSION}"
      tmux -V
      shift
      exit 0
      ;;
    -*)
      echo "Unrecognized command: ${1}"
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

test ${debug} = "true" && set -x

if test -r ${TMRC} ; then
  source ${TMRC}
fi

case ${cmd} in
  kill)
    test $# -lt 1 && { echo "Session name required." ; exit 1 ; }
    cmd_kill ${1}
    ;;

  kill-server)
    cmd_kill_server
    ;;

  start-server)
    cmd_start_server
    ;;

  list)
    cmd_list
    ;;

  ls)
    cmd_ls
    ;;

  cmd)
    cmd_cmd ${1:-${TM_DEFAULT_CMD}}
    ;;

  *)
    echo "Unrecognized command: ${cmd}"
    exit 1
    ;;
esac

exit 0
