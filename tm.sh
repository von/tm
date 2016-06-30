#!/bin/bash
#
# tm: Create new tmux sessions or windows

TM_VERSION="0.9"

TMRC=${TMRC:-${HOME}/.tmux/tmrc}
TM_CMD_PATH=${TM_CMD_PATH:-${HOME}/.tmux/tm}
TM_DEFAULT_CMD="default"

# These can be overridden by ~/.tmux/tmrc
TMUX_CMD="tmux"
TMUX_ARGS=""

######################################################################
#
# These functions meant to be called from inside sourced command script
#
# These functions use the following globals:
#   TM_SESSION : the name of the last session created
#   TM_WINDOW : the name of the last window created
#   TM_PANE : the name of the last pane created

# Send text, presumably a command, to current pane
# Usage: tm_cmd <text to send>
tm_cmd()
{
  local _cmd=${*}
  # IF $TM_PANE is not set, use "+0" for current pane
  ${TMUX_CMD} ${TMUX_ARGS} send-keys \
    ${TM_LAST_PANE:+-t ${TM_LAST_PANE}} "${_cmd}" "Enter"
}

# Create new session and attach to it
# Usage: new_session <session_name> [<args as 'tmux new-session'>]
# If session already exists, returns 1
tm_new_session()
{
  # Leading colon means silent errors, script will handle them
  # Colon after a parameter, means that parameter has an argument in $OPTARG
  local _args=""
  while getopts ":ADEPc:F:n:s:t:x:y:" opt; do
    case $opt in
      A|d|D|E|P) _args+=" -${opt}" ;;
      d) ;; # Ignore, we created detached as part of process
      c|F|n|t|x|y) _args+=" -${opt} ${OPTARG}" ;;
      s) ;;  # Ignore, set name from other arguments
    esac
  done

  shift $(($OPTIND - 1))
  local _session=$1; shift
  tm_check_session ${_session} && return 1 || true

  # Start new detached session. Unsets TMUX so may be called inside of
  # tmux session.
  (unset TMUX && \
    ${TMUX_CMD} ${TMUX_ARGS} \
      new-session -d -s ${_session} ${_args} "$@")

  tm_select_session ${_session}
  TM_SESSION="${_session}"
  TM_LAST_WINDOW="${_session}"
  TM_LAST_PANE="${_session}"
}

# Create a new independant session attached to given target session
# Usage: <target session>
#
# This is an improved version of:
# https://mutelight.org/practical-tmux
tm_new_independant_session()
{
  local target_session=$1; shift

  # Find unused session name by appending incrementing index
  # Starting with 2 seems most natural, but value is arbitrary
  local _index=2
  until tmux_new_session -t ${target_session} \
    ${target_session}-${_index} 2>/dev/null \
    ; do
    _index=$((_index+1))
  done
  local _session=${target_session}-${_index}
  tm_select_session ${_session}
  TM_SESSION="${_session}"
  TM_LAST_WINDOW="${_session}"
  TM_LAST_PANE="${_session}"
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

# Return 0 if session already exists, else 1
# Usage: tm_check_session <session name>
tm_check_session()
{
  local _session_name=${1}; shift
  ${TMUX_CMD} ${TMUX_ARGS} list-sessions -F "#S" | \
    grep -q -x "${_session_name}" && return 0
  return 1
}

# Return 0 if window already exists in current session, else 1
# Usage: tm_check_window <window name>
tm_check_window()
{
  local _window_name=${1}; shift
  ${TMUX_CMD} ${TMUX_ARGS} list-windows \
    ${TM_SESSION:+-t ${TM_SESSION}} -F "#W" \
    | grep -q -x "${_window_name}" && return 0
  return 1
}

# Return current session name
# Usage: tm_current_session_name
# Outputs session name as string
tm_current_session_name()
{
  # Just list session of current session's windows, take first
  tmux list-windows ${TM_SESSION:+-t ${TM_SESSION}} -F "#S" | head -1
}

# Create a new window
# Usage: tm_new_window <args as to 'tmux new-window'>
tm_new_window()
{
  # -P = print new window information
  TM_LAST_WINDOW=$(${TMUX_CMD} ${TMUX_ARGS} new-window -P \
    ${TM_SESSION:+-t ${TM_SESSION}} "${@}")
  TM_LAST_PANE=${TM_LAST_WINDOW}
}

# Select given pane
# Usage: tm_select_pane <target pane>
tm_select_pane()
{
  local _target=${1}
  # Select given pane in our session, current window
  ${TMUX_CMD} ${TMUX_ARGS} select-pane -t :.${_target}
  TM_LAST_PANE=${_target}
}

# Select given window
# Usage: tm_select_window <wondow_name>
tm_select_window()
{
  local _name=${1}
  ${TMUX_CMD} ${TMUX_ARGS} select-window -t :${_name}
  TM_LAST_WINDOW=${_name}
  TM_LAST_PANE=${TM_LAST_WINDOW}
}


# Select or attach to given session
# Usage: select_session <session name>
tm_select_session()
{
  local _session=${1}
  tm_check_session ${_session} || return 1

  # If in tmux already, does a 'switch-client' instead
  if test -n "${TMUX:-}" ; then
    ${TMUX_CMD} ${TMUX_ARGS} switch-client -t ${_session}
  else
    ${TMUX_CMD} ${TMUX_ARGS} attach-session -t ${_session}
  fi
  TM_SESSION=${_session}
  TM_LAST_WINDOW=${_session}
  TM_LAST_PANE=${_session}
}

# split window horizontally
# Usage: tm_splith [<options>]
tm_splith()
{
  TM_LAST_PANE=$(${TMUX_CMD} ${TMUX_ARGS} split-window -h -P \
    ${TM_LAST_PANE:+-t ${TM_LAST_PANE}} "${@}")
}

# Split window vertically
# Usage: tm_splitv [<options>]
tm_splitv()
{
  TM_LAST_PANE=$(${TMUX_CMD} ${TMUX_ARGS} split-window -v -P \
    ${TM_LAST_PANE:+-t ${TM_LAST_PANE}} "${@}")
}

# Kill given session
# Usage: tm_kill_session <session_name>
tm_kill_session()
{
  local _session=${1}
  ${TMUX_CMD} ${TMUX_ARGS} kill-session -t "${_session}"
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
  ${TMUX_CMD} ${TMUX_ARGS} kill-server
}

cmd_cmd()
{
  local _cmd=${1}
  local _cmd_file=${TM_CMD_PATH}/${_cmd}

  if test -r ${_cmd_file} ; then
    source ${_cmd_file} ${_cmd}
  else
    echo "Unknown command \"${_cmd}\""
    exit 1
  fi
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
    -ls)  # List sessions we have configuration files for
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
