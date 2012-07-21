tm
==========

tm is a tmux session manager. It does two things:

1) Allows scripted starts of sessions like [tmuxinator][] or
[teamocil][] (but admittedly not as well)

2) Starts a session if it is not running, or attached to a running
session with a new independent session.

Usage
----------

    tm [<session name>]

If *session name* is not provided, the name "default" is used.

Scripted Sessions
----------

If a session is started and ~/.tmux/sessions/*session name* exists, it
is invoked with the expectation it will create and attach to the
session.

This is the weakest part of tm, it really should just use
teamocil. Figuring out how to integrate the two is a TODO.

Example session script. This session file creates a session with one
window, two panes. It changes the directory in the bottom and selects
the top.

    SESSIONNAME=test
    cd ~/develop
    tmux new-session -d -s ${SESSIONNAME}
    tmux split-window -v
    tmux send-keys "cd /tmp" "Enter"
    tmux select-pane -t 0
    tmux attach-session -t ${SESSIONNAME}

Attaching to Running Sessions
----------

If tm is run with the name of a session that is already running, but
has no clients attached, it will simply be attached to.

If tm is run with the name of a session that is already running, but
has one or more clients already attached, a new session will be
created that is attached to the target session. This allows the new
session to view windows in the first session independently of existing
clients. The new session will be named *session name-N* where N is a
number such that the name is unique.


[teamocil]: https://github.com/remiprev/teamocil

[tmuxinator]: https://github.com/aziz/tmuxinator/
