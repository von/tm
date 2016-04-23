#!/bin/bash
#
# tm: Start tmux sessions

TM_VERSION="0.6"

TM_SESSION_PATH=${TM_SESSION_PATH:-${HOME}/.tmux/sessions}
TM_INIT_PATH=${TM_INIT_PATH:-${HOME}/.tmux/init}
TM_DEFAULT_SESSION="default"

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
  local _cmd=""

  # Turn args into one quoted string
  # Kudos: http://stackoverflow.com/a/8723305/197789
  local _arg
  for _arg in "$@" ; do
    _cmd="$_cmd \"${_arg//\"/\\\"}\""  #" (vim syntax fix)
  done

  if test -n "${TMUX:-}" ; then
    # Inside of tmux, start session and attach so it susequent
    # commands go to it by default.
    (unset TMUX && ${TMUX_CMD} ${TMUX_ARGS} ${_verbose} new-session -d -s ${_session} ${_cmd})
  else
    # Outside of tmux, just start detached session...
    ${TMUX_CMD} ${TMUX_ARGS} ${_verbose} new-session -d -s ${_session} ${_args} ${_cmd}
  fi
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

tm_new_session()
{
  local _session=${1}
  local _startup_file=${TM_SESSION_PATH}/${_session}

  echo "Creating new session ${_session}"
  if test -r ${_startup_file} ; then
    echo "Configuring using ${_startup_file}"
    source ${_startup_file} ${_session}
  else
    tmux_new_session ${_session}
  fi
}

tm_new_independant_session()
{
  # Create a new independant session attached to given target session
  #
  # This is an improved version of:
  # https://mutelight.org/practical-tmux
  #
  # Usage: <session>
  # outputs: <new session>

  # Find unused session name by appending incrementing index
  # Starting with 2 seems most natural, but value is arbitrary
  _index=2
  until tmux_new_session -t ${_session} ${_session}-${_index} 2>/dev/null ; do
    _index=$((_index+1))
  done
  _target_session=${_session}-${_index}
  echo ${_target_session}
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

cmd()  # Send a command to current pane
{
  # Usage: cmd <command to send to window>
  local _cmd=${*}
  ${TMUX_CMD} ${TMUX_ARGS} send-keys -t ${_last_window} "${_cmd}" "Enter"
}

new_session()  # Create new session
{
  # Usage: new_session [-n <window-name>] <session name> [<cmd>]
  tmux_new_session "$@"
  _last_window=${1}  # XXX, this is broken if window_name given
}

new_window()  # Create a new window, args as 'tmux new-window'
{
  # -P = print new window information
  local _args="-P -t ${_session}"
  _last_window=$(${TMUX_CMD} ${TMUX_ARGS} new-window ${_args} "${@}")
}

select_pane()  # Select given pane
{
  # Usage select_pane <target>
  local _target=${1}
  # Select given pane in our session, current window
  ${TMUX_CMD} ${TMUX_ARGS} select-pane -t ${_session}:.${_target}
}

select_window()  # Select given window
{
  # Usage: select_window <name>
  local _name=${1}
  ${TMUX_CMD} ${TMUX_ARGS} select-window -t ${_session}:${_name}
  _last_window=${_name}
}

splith()  # split window horizontally
{
  # Usage: splith [<options>]
  ${TMUX_CMD} ${TMUX_ARGS} split-window -h -t ${_last_window} "${@}"
}

splitv()  # Split window vertically
{
  # Usage: splitv [<options>]
  ${TMUX_CMD} ${TMUX_ARGS} split-window -v -t ${_last_window} "${@}"
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

tm_list()  # List running sessions
{
  _session=${1}

  ${TMUX_CMD} ${TMUX_ARGS} -q list-sessions 2> /dev/null | cut -f 1 -d ':'
}

tm_ls()  # List sessions we have configuration files for
{
  (test -d ${TM_SESSION_PATH} && cd ${TM_SESSION_PATH} && ls -1 ;
    test -d ${TM_INIT_PATH} && cd ${TM_INIT_PATH} && ls -1) | \
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

tm_start()
{
  _session=${1}

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
    tm_new_session ${_session}
  fi

  tmux_attach_session ${_session}

  # Clean up targetted session if we started it
  if test -n "${_target_session:-}" ; then
    echo "Cleaning up ${_target_session}"
    ${TMUX_CMD} ${TMUX_ARGS} kill-session -t ${_target_session}
  fi
}

######################################################################
#
# Main

set -e  # Exit on error

# Command
cmd="start"

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

_session=${1:-${TM_DEFAULT_SESSION}}

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

  start)
    tm_start ${_session}
    ;;

  *)
    echo "Unrecognized command: ${cmd}"
    exit 1
    ;;
esac

exit 0
