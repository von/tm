#!/bin/sh
#
# tm: Start tmux sessions

TM_SESSION_PATH=${TM_SESSION_PATH:-${HOME}/.tmux/sessions}

function tm_attach_existing()
{
    local _session=${1}

    if tmux ls | grep ${_session}: | grep "(attached)" > /dev/null ; then
        # There is a client attached to the target session, open
        # a second session attached to the target. Use a different
        # session so that they are independent (i.e. they could each
        # view a different window).

        # Find unused session name by appending incrementing index
        # Starting with 2 seems most natural, but value is arbitrary
        local _index=2
        until tmux new-session -d -t ${_session} -s ${_session}-${_index} 2>/dev/null ; do
            _index=$((_index+1))
        done
        local _my_session=${_session}-${_index}
        echo "Attaching to existing session ${_session} via ${_my_session}"
        tmux attach-session -t ${_my_session}
        echo "Cleaning up ${_my_session}"
        tmux kill-session -t ${_my_session}
    else
        # No current client, just attached directly to session.
        echo "Attaching to existing session ${_session}"
        tmux attach-session -t ${_session}
    fi
}

function tm_new_session()
{
    local _startup_file=${TM_SESSION_PATH}/${_session}

    if test -r ${_startup_file} ; then
        echo "Creating new session ${_session} using ${_startup_file}"
        (source ${_startup_file})
    else
        echo "Creating new session ${_session}"
        tmux new-session -s ${_session}
    fi
}

######################################################################
#
# Main


case ${1} in
    -ls)
        ls -1 ${TM_SESSION_PATH} | grep -v "~$"
        exit 0
        ;;
    -*)
        echo "Unrecognized command: ${1}"
        exit 1
        ;;
    *)
        _session=${1:-default}
        if tmux has -t ${_session} >/dev/null 2>&1 ; then
            tm_attach_existing "${_session}"
        else
            tm_new_session "${_session}"
        fi
        ;;
esac

exit 0

