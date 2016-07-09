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

# Return 0 if session already exists, else 1
# Usage: tm_check_session <session name>
tm_check_session()
{
  local _session_name=${1}; shift
  tm_check_server || return 1
  ${TMUX_CMD} ${TMUX_ARGS} list-sessions -F "#S" | \
    grep -q -x "${_session_name}" && return 0
  return 1
}

# Return 0 if window already exists in current session, else 1
# Usage: tm_check_window <window name>
tm_check_window()
{
  local _window_name=${1}; shift

  tm_check_server || return 1

  ${TMUX_CMD} ${TMUX_ARGS} list-windows \
    ${TM_SESSION:+-t ${TM_SESSION}} -F "#W" \
    | grep -q -x "${_window_name}" && return 0
  return 1
}

# Return current session name
# Usage: tm_current_session_name
# Outputs session name as string
# Returns 1 if there is no current session
tm_current_session_name()
{
  tm_check_server || return 1
  # Just list session of current session's windows, take first
  ${TMUX_CMD} ${TMUX_ARGS} list-windows \
    ${TM_SESSION:+-t ${TM_SESSION}} -F "#S" | head -1
}

# Return current window name
# Usage: tm_current_window_name
# Outputs window name as string
tm_current_window_name()
{
  tm_check_server || return ""
  # Just list session of current window's panes, take first
  ${TMUX_CMD} ${TMUX_ARGS} list-panes \
    ${TM_LAST_PANE:+-t ${TM_LAST_PANE}} -F "#W" | head -1
}

# Select given pane
# Usage: tm_select_pane <target pane>
tm_select_pane()
{
  local _target=${1}
  tm_check_server || { echo "No tmux server running." 1>&2 ; return 1 ; }
  # Select given pane in our session, current window
  ${TMUX_CMD} ${TMUX_ARGS} select-pane \
    -t .${_target}
  TM_LAST_PANE=${_target}
}

# Select given window
# Usage: tm_select_window <wondow_name>
tm_select_window()
{
  local _name=${1}
  tm_check_server || { echo "No tmux server running." 1>&2 ; return 1 ; }
  ${TMUX_CMD} ${TMUX_ARGS} select-window \
    -t ${TM_SESSION:+${TM_SESSION}}:${_name}
  TM_LAST_WINDOW=${_name}
  TM_LAST_PANE=${TM_LAST_WINDOW}
}

# Select or attach to given session
# Usage: select_session <session name>
tm_select_session()
{
  local _session=${1}
  tm_check_server || { echo "No tmux server running." 1>&2 ; return 1 ; }
  tm_check_session ${_session} || return 1

  # Use attach-session as it works if we have a tmux session
  # already running or not.
  ${TMUX_CMD} ${TMUX_ARGS} attach-session -t ${_session}
  TM_SESSION=${_session}
  TM_LAST_WINDOW=${_session}
  TM_LAST_PANE=${_session}
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
