#!/bin/bash
#
# tm: Create new tmux sessions or windows

TM_VERSION="0.9"

TM_CMD_PATH=${TM_CMD_PATH:-${HOME}/.tmux/tm}
TM_DEFAULT_CMD="default"

# These can be overridden by ~/.tmux/tmrc
TMUX_CMD="tmux"
TMUX_ARGS=""

tmux_new_session()
{
  # Start new detached session. Unsets TMUX so may be called inside of
  # tmux session.
  #
  # Usage: [-t <target session>] [-n <window name>] <session> [<cmd>]
  local _args=""
  while true ; do
    case ${1:-} in
      -n)
        _args="-n ${2}"
        shift 2
        ;;
      -t)
        _args="-t ${2}"
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done

  local _verbose=""
  if test ${verbose} == "true" ; then
    _verbose="-v"
  fi

  local _session=${1} ; shift

  (unset TMUX && \
    ${TMUX_CMD} ${TMUX_ARGS} ${_verbose} \
      new-session -d -s ${_session} ${_args} "$@")
}

tmux_attach_session()
{
  # Attach to existing session.
  # If in tmux already, does a 'switch-client' instead
  local _session=${1}
  if test -n "${TMUX:-}" ; then
    ${TMUX_CMD} ${TMUX_ARGS} switch-client -t ${_session}
  else
    ${TMUX_CMD} ${TMUX_ARGS} attach-session -t ${_session}
  fi
}

tm_new_independant_session()
{
  # Create a new independant session attached to given target session
  #
  # This is an improved version of:
  # https://mutelight.org/practical-tmux
  #
  # Usage: <target session>
  # outputs: <new session>

  local target_session=$1; shift

  # Find unused session name by appending incrementing index
  # Starting with 2 seems most natural, but value is arbitrary
  _index=2
  until tmux_new_session -t ${target_session} \
    ${target_session}-${_index} 2>/dev/null \
    ; do
    _index=$((_index+1))
  done
  echo ${target_session}-${_index}
}

tm_check_server()
{
  # Return 0 if server already running, else 1
  if ${TMUX_CMD} ${TMUX_ARGS} ls >/dev/null 2>&1 ; then
    return 0
  fi
  return 1
}

######################################################################
#
# These functions meant to be called from inside sourced startup script
#
# These functions use the following globals:
#   _last_window : the name of the last window created.
#   _session : the name of session

# Send a command to current pane
cmd()
{
  # Usage: cmd <command to send to window>
  local _cmd=${*}
  ${TMUX_CMD} ${TMUX_ARGS} send-keys -t ${_last_window} "${_cmd}" "Enter"
}

# Create new session or attach to existing session
new_session()
{
  # Usage: new_session <session_name> [<args as 'tmux new-session'>]
  local _session=$1; shift
  #_last_window=$(${TMUX_CMD} ${TMUX_ARGS} new-session -P "${@}")

  # Is the session already running?
  if ${TMUX_CMD} ${TMUX_ARGS} has -t ${_session} > /dev/null 2>&1 ; then
    # Yes it is...
    if test ${independent} = "true" ; then
      # We want a session independent of any session already running.
      # Does session already have a client?
      if ${TMUX_CMD} ${TMUX_ARGS} ls | grep ${_session}: | grep "(attached)" > /dev/null ; then
        # Yes, need to establish new session.
        if test -n "${TMUX:-}" ; then
          # No way to clean up if we are inside of tmux since
          # switch-client returns immediately.
          echo "Cannot establish independant session inside of tmux"
          exit 1
        fi
        echo "Creating new independent session for ${_session}"
        _target_session=$(tm_new_independant_session ${_session})
        echo "Attaching to ${_session} via ${_target_session}"
        _session=${_target_session}
      else
        # Session has no client, attach as normal
        echo "Attaching to ${_session}"
      fi
    else
      # Don't want independent, attach as normal
      echo "Attaching to ${_session}"
    fi
  else
    # Session is not running start it...
    tmux_new_session ${_session}
  fi

  tmux_attach_session ${_session}

  # Clean up targetted session if we started it
  if test -n "${_target_session:-}" ; then
    echo "Cleaning up ${_target_session}"
    ${TMUX_CMD} ${TMUX_ARGS} kill-session -t ${_target_session}
  fi
}

# Create a new window, args as 'tmux new-window'
new_window()
{
  # -P = print new window information
  _last_window=$(${TMUX_CMD} ${TMUX_ARGS} new-window -P "${@}")
}

# Select given pane
select_pane()
{
  # Usage select_pane <target>
  local _target=${1}
  # Select given pane in our session, current window
  ${TMUX_CMD} ${TMUX_ARGS} select-pane -t ${_session}:.${_target}
}

# Select given window
select_window()
{
  # Usage: select_window <name>
  local _name=${1}
  ${TMUX_CMD} ${TMUX_ARGS} select-window -t :${_name}
  _last_window=${_name}
}

# split window horizontally
splith()
{
  # Usage: splith [<options>]
  _last_window=$(${TMUX_CMD} ${TMUX_ARGS} split-window -h -P -t ${_last_window} "${@}")
}

# Split window vertically
splitv()
{
  # Usage: splitv [<options>]
  _last_window=$(${TMUX_CMD} ${TMUX_ARGS} split-window -v -P -t ${_last_window} "${@}")
}

######################################################################
#
# Top-level commands
#

tm_help()
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
tm_list()
{
  _session=${1}

  ${TMUX_CMD} ${TMUX_ARGS} -q list-sessions 2> /dev/null | cut -f 1 -d ':'
}

# List sessions we have configuration files for
tm_ls()
{
  (test -d ${TM_CMD_PATH} && cd ${TM_CMD_PATH} && ls -1 ) | \
    grep -v -e "~$" | grep -v -e "^#.*#$" | sort | uniq
}

tm_kill()
{
  _session=${1}

  ${TMUX_CMD} ${TMUX_ARGS} kill-session -t "${1}" || exit 1
}

tm_kill_server()
{
  ${TMUX_CMD} ${TMUX_ARGS} kill-server
}

tm_cmd()
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

# Start independent session?
independent="false"

verbose="false"

while true; do
  case ${1:-""} in
    -h)
      tm_help
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
    -i)
      independent="true"
      shift
      ;;
    -I)
      independent="false"
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

TMRC=${HOME}/.tmux/tmrc
if test -r ${TMRC} ; then
  source ${TMRC}
fi

_cmd=${1:-${TM_DEFAULT_CMD}}

case ${cmd} in
  kill)
    tm_kill ${_session}
    ;;

  kill-server)
    tm_kill_server
    ;;

  list)
    tm_list ${_session}
    ;;

  ls)
    tm_ls ${_session}
    ;;

  cmd)
    tm_cmd ${_cmd}
    ;;

  *)
    echo "Unrecognized command: ${cmd}"
    exit 1
    ;;
esac

exit 0
