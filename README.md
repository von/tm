tm
==========

tm is a tmux session manager. It does the following:

1) Allows scripted starts of sessions like [tmuxinator][] or
[teamocil][]

2) Starts a session if it is not running, or attaches to a running
session, optionally with a new independent session.

3) Allows for scripted start of the tmux server, so its environment
can be specified.

Usage
----------

    tm [-ls] [-i] [-k] [<session name>]

If *session name* is not provided, the name "default" is used.

If `-i` is provided, and if tm ends up attaching to an existing
session, it will do so by creating a new session that targets the
desired session so that it is independent (has its own view).  See the
section "Attaching to Running Sessions."

If '-k' is provided, the given session (or 'default' if no session
name is give) is killed. This is equivalent to 'tmux kill-session -t
*session name*'.

If `-ls` is provided, tmux will list all available session start up
files it knows about (see session on "Scripted Sessions") and
exit. This is intended for use with auto-completion.

Scripted Sessions
----------

If tm starts a session and ~/.tmux/sessions/*session name* exists, it
is invoked after the session is started and can configure the session
by creating windows, splitting windows, running commands in panes,
etc.

The script is a bash shell script with some helper functions defined
as follows:

`new_session [-n <window name>] <session name> [<cmd>]`

This must be the first command in the file to create the session.
It may optionally specify the name and command to be run in the
initial window created.

`cmd <command...>`

Send all arguments to the currently selected pane as key strokes. A
carriage return will be added. (Wrapper around `tmux send-keys`)

`new_window [-n <name>]`

Create a new window with option name. (Wrapper around `tmux
new-window`)

`select_pane <pane>`

Select the given pane in the current window. (Wrapper around `tmux
select-pane`)

`select_window <name>]`

Cause the named pane to have focus. select_ commands must be the last
things run in the script to be effective. (Wrapper around `tmux
select-window`)

`splith [<options>]`

Split the current window horizontally. Any options will be passed to
the tmux `split-window` command. (Wrapper around `tmux split -h`)

`splitv [<options>]`

Split the current window vertically. Any options will be passed to
the tmux `split-window` command. (Wrapper around `tmux split -v`)

Example session script.
----------

    # Create two windows, the first split into top and bottom panes, the
    # second into left and right.
    new_session -n win1 example
    cmd cd ~/develop
    splitv
    cmd cd /tmp

    new_window win2
    splith

    # Focus on first window, top pane
    # (Can use window name if you don't automatically rename them)
    select_window 0
    select_pane top

Attaching to Running Sessions
----------

If tm is run with the name of a session that is already running, but
has no clients attached, it will simply be attached to.

If tm is run with the name of a session that is already running and
the `-i` option is not specified, it will simply attach.

If tm is run with `-i` and the target session exists, a new
independent session will be created that is attached to the target
session and the new session will be attached to, giving the client
freedom from other clients to view windows independently.  The new
session will be named *session name-N* where N is a number such that
the name is unique. When the client detaches, the independent session
will be cleaned up (killed).

Starting the tmux server
--------

If you run tm and a tmux server is not running, it will start one with
the session `default` (running the start script for `default` if it
exists).

If the script `~/.tmux/start-server` exists, it will be run to start
the server instead. The intent is that is sets up a specific
environment for the server rather than inheriting what is in the
current environment. The script can do whatever it likes, it just
needs to make sure when it finishes, a tmux server is running.

Running Inside of tmux
--------
You can run tm inside or outside of tmux and it will behave the
same. If you run it inside, it will create or attach to new sessions
on the existing server.

If you run tm outside of tmux, it will start the server if needed (see
the previous section) and start or attach to the specified session as
appropriate.

The only difference is you cannot create independent sessions from
inside of tmux, so if you specify `-i` and a new session is needed,
you will get an error. (The reason for this is that there is no way to
clean up the independent session in that case.)

~/.tmux/tmrc
------

If `~/.tmux.tmrc` exists it will be sourced by tm. tmrc can define
functions that can be called in session scripts or set other
environment variables.

Bash Auto-Completion
------

If you source bash_completion.sh you will get auto-completion with
bash. That is, `tm <tab>` will list both all running sessions you can
attach to and all sessions that tm knows about based on start up scripts.

ZSH Auto-Completion
------

The file '\_tm' provides autocompletion for zsh. To utilize it, place
the file in a directory which is included in your 'fpath',
e.g. assuming '\_tm' is in '~/tm/':

    fpath=( ~/tm/ $path)

[teamocil]: https://github.com/remiprev/teamocil

[tmuxinator]: https://github.com/aziz/tmuxinator/
