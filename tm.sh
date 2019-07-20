#!/bin/bash
#
# tm: Create new tmux sessions or windows

TM_VERSION="0.14.0"

# Default tmrc file
TMRC=${TMRC:-${HOME}/.tmux/tmrc}

######################################################################
# These can be overridden by tmrc file

# Path to tm command files
TM_CMD_PATH=${TM_CMD_PATH:-${HOME}/.tmux/tm}

# Default tm command if none given
TM_DEFAULT_CMD="default"

# Session and window name to use if starting tmux server
TM_START_WINDOW_NAME=${TM_START_WINDOW_NAME:-tm-window}
TM_START_SESSION_NAME=${TM_START_SESSION_NAME:-tm-session}

# tmux binary name
TMUX_CMD=${TMUX_CMD:-"tmux"}

# tmux arguments
TMUX_ARGS=${TMUX_ARGS:-""}

######################################################################
#
# Source command file
# Usage: tm_cmd [-D] <filename>
#   -D  Don't check for running sever
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
# Handles "@tm-try: <tmux command>" directive
# Handles "@tm-attach: <tmux command>" directive
tm_process_cmd_file()
{
  local _cmd_file="${1}"
  local _try_cmd=$(sed -n "s/^#@tm-try: \(.*\)$/\1/p" ${_cmd_file})
  local _attach_cmd=$(sed -n "s/^#@tm-attach: \(.*\)$/\1/p" ${_cmd_file})
  if test -n "${TMUX}" ; then
    # We are attached, tm-try try command and return if succeeds.
    if test -n "${_try_cmd}" ; then
      ${TMUX_CMD} ${TMUX_ARGS} ${_try_cmd} >& /dev/null && return 0
      # tm-try command failed, fall through to sourcing command file.
    fi
  else
    # We are not attached, try to attach if we have a tm-attach command
    if test -n "${_attach_cmd}" ; then
      ${TMUX_CMD} ${TMUX_ARGS} ${_attach_cmd} >& /dev/null && return 0
    fi
    # Fall back to attaching to tm's session
    ${TMUX_CMD} ${TMUX_ARGS} \
      attach-session -t ${TM_START_SESSION_NAME} \; \
      source-file ${_cmd_file}
    return $?
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
  # Allow the following to fail, which it may if we're starting two sessions at the
  # same time, in which case we have a race condiction that can result in trying to
  # create the session twice.
  ${TMUX_CMD} ${TMUX_ARGS} new-session -d \
    -n ${TM_START_WINDOW_NAME} -s ${TM_START_SESSION_NAME} || true
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
  -d       Turn on debugging.
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
    if test $# -eq 0 ; then
      cmd_cmd ${TM_DEFAULT_CMD}
    else
      for c in "$@" ; do
        cmd_cmd ${c}
      done
    fi
    ;;

  *)
    echo "Unrecognized command: ${cmd}"
    exit 1
    ;;
esac

exit 0
