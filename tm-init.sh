#
# Tmux session specific initialization
#
# If we are in a tmux session, and ~/.tmux/init/<session name> exists
# source it. This allows every shell started in a session to do some
# common initialization.
#
# Source this file from your bashrc or zshrc after any other
# initialization so that aliases, paths, etc. are set up as needed by
# your init scripts.
#
# Also adds some helper functions if we are running in a tmux session.
#
# Kudos to the following for how to print session name, window name
# and pane title: http://betabug.ch/blogs/bsdcow/48

if test -n "${TMUX}" ; then
    # We are in tmux...

    # Only do tmux initialization once (not again if bashrc is resourced)
    if test -z "${TMUX_INIT_COMPLETE}" ; then
        TMUX_INIT_COMPLETE=1

        TMUX_INIT_PATH=${HOME}/.tmux/init/
        TMUX_SESSION_INIT_FILE=${TMUX_INIT_PATH}/${TMUX_SESSION_NAME}
        if test -e "${TMUX_SESSION_INIT_FILE}" ; then
            source ${TMUX_SESSION_INIT_FILE}
        fi
    fi

    # Print name of tmux session
    tmux_session_name () {
        # This handles multiple panes in a window and running in a pane
        # that is not currently the active pane.
        tmux list-panes -t ${TMUX_PANE} -F "#{pane_id} #{session_name}" | \
            grep -e "^${TMUX_PANE}" | cut -d ' ' -f 2-
    }

    # Print name of tmux window
    tmux_window_name () {
        # This handles multiple panes in a window and running in a pane
        # that is not currently the active pane.
        tmux list-panes -t ${TMUX_PANE} -F "#{pane_id} #{window_name}" | \
            grep -e "^${TMUX_PANE}" | cut -d ' ' -f 2-
    }

    # Print name of tmux pane
    tmux_pane_title () {
        # This handles multiple panes in a window and running in a pane
        # that is not currently the active pane.
        tmux list-panes -t ${TMUX_PANE} -F "#{pane_id} #{pane_title}" | \
            grep -e "^${TMUX_PANE}" | cut -d ' ' -f 2-
    }

    # Set current pane title to arguments.
    tmux_set_pane_title() {
      printf "\033]2;${*}\033\\"
    }
fi
