#!/bin/sh
#
# tm: Start tmux sessions

TM_SESSION_PATH=${TM_SESSION_PATH:-${HOME}/.tmux/sessions}
TM_DEFAULT_SESSION="default"

# Force 256 colors
export TERM="xterm-256color"

tmux_new_session()
{
    # Start new detached session. Unsets TMUX so may be called inside of
    # tmux session.
    #
    # Usage: [-t <target session>] <session>
    local _args=""
    if test ${1:-} = "-t"; then
	_args="-t ${2}"
	shift 2
    fi
    local _session=${1}
    (unset TMUX && tmux new-session -d ${_args} -s ${_session})
}

tmux_attach_session()
{
    # Attach to existing session.
    # If in tmux already, does a 'switch-client' instead
    local _session=${1}
    if test -n "${TMUX:-}" ; then
	# In tmux...
	tmux switch-client -t ${_session}
    else
	tmux attach-session -t ${_session}
    fi
}

tm_new_session()
{
    local _session=${1}
    local _startup_file=${TM_SESSION_PATH}/${_session}

    echo "Creating new session ${_session}"
    tmux_new_session ${_session}
    if test -r ${_startup_file} ; then
	echo "Configuring using ${_startup_file}"
	source ${_startup_file} ${_session}
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
    if tmux ls >/dev/null 2>&1 ; then
	return 0
    fi
    return 1
}

tm_start_server()
{
    local _server_script=~/.tmux/start-server
    if test -r ${_server_script} ; then
	echo "Starting tmux server via ${_server_script}"
	(source ${_server_script})
    else
	echo "Starting tmux server with session ${TM_DEFAULT_SESSION}"
	local _tmux=$(which tmux)
	bash -l -c "cd ${HOME} && ${_tmux} new-session -d -s ${TM_DEFAULT_SESSION}"
    fi
}

######################################################################
#
# These functions meant to be called from inside sourced startup script
#

cmd()  # Send a command to current pane
{
    # Usage: cmd <command to send to window>
    local _cmd=${*}
    tmux send-keys "${_cmd}" "Enter"
}

main_window()  # Configure the main window (window 0)
{
    # Usage: main_window [<window name>]
    local _name=${1:-}
    tmux select-window -t 0
    if test -n "${_name:-}" ; then
        tmux rename-window ${_name}
    fi
}

new_window()  # Create a new window with optional name
{
    # Usage: new_window [<window name>]
    local _name=${1:-}
    if test -n "${_name:-}" ; then
        tmux new-window -n ${_name}
    else
        tmux new-window
    fi
}

select_pane()  # Select given pane
{
    # Usage select_pane <target>
    local _target=${1}
    tmux select-pane -t ${_target}
}

select_window()  # Select given window
{
    # Usage: select_window <name>
    local _name=${1}
    tmux select-window -t ${_name}
}

splith()  # split window horizontally
{
    # Usage: splith [<options>]
    tmux split-window -h "${*:-}"
}

splitv()  # Split window vertically
{
    # Usage: splitv [<options>]
    tmux split-window -v "${*:-}"
}

######################################################################
#
# Main

set -e  # Exit on error
set -u  # Use of unitialized variable is an error

# Start independent session?
independent="false"

while true; do
    case ${1:-""} in
	-ls)
	    ls -1 ${TM_SESSION_PATH} | grep -v "~$"
            shift
	    exit 0
	    ;;
	-i)
	    independent="true"
            shift
	    ;;
	-I)
	    independent="false"
            shift
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

_session=${1:-${TM_DEFAULT_SESSION}}

# Make sure server is running
if tm_check_server ; then
    :  # Server running
else
    tm_start_server
fi

# Is the session already running?
if tmux has -t ${_session} > /dev/null 2>&1 ; then
    # Yes it is...
    if test ${independent} = "true" ; then
        # We want a session independent of any session already running.
	# Does session already have a client?
	if tmux ls | grep ${_session}: | grep "(attached)" > /dev/null ; then
            # Yes, need to establish new session.
	    if test -n "${TMUX:-}" ; then
                # No way to clean up if we are inside of tmux since
                # switch-client returns immediately.
		echo "Cannot establish independant session inside of tmux"
		exit 1
	    fi
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
    tmux kill-session -t ${_target_session}
fi

exit 0
