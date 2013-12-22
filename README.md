tm
==========

tm is a tmux session manager. For the latest version, please see its
github page: https://github.com/von/tm

tm does the following:

1) Allows scripted starts of sessions like [tmuxinator][] or
[teamocil][]

2) Starts a session if it is not running, or attaches to a running
session, optionally with a new independent session.

tm uses bash scripts for all of the tasks, allow the user a great deal
of flexibility and power. tm provides helper functions to automate
common tmux actions to ease writing these scripts. No configuration is
needed to start using tm.

Unlike tmux, tm can be used inside of a tmux session, allowing it to
be used to switch or create sessions from the command-line easily.

Usage
----------

    tm [<options>] [<session name>]

If *session name* is not provided, the contents of the
*TM_DEFAULT_SESSION* environment variable is used; if that variable is
not set, the name "default" is used.

The following options are also supported:

'-h' Print help and exit.

'-i` When Attaching to an existing session, do so by creating a new
session that targets the desired session so that it is independent
(has its own view).  See the section "Attaching to Running Sessions."

'-I' When Attaching to an existing session, do so directly without
creating an independent session. This is the default.  See the section
"Attaching to Running Sessions."

'-k' Kill the given session. This is equivalent to 'tmux kill-session
-t *session name*'.

'-K' Kill the tmux server and exit.

'-l' List all running sessions and exit. This is equivalent to 'tmux list-sessions'.

`-ls` List all available session start up files (see session on "Scripted Sessions") and
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

`default_path <path>`

Set the default path for new panes/windows for the current session.

`new_window [<args>]`

Create a new window. (Wrapper around `tmux new-window`)

`select_pane <pane>`

Select the given pane in the current window. (Wrapper around `tmux
select-pane`)

`select_window <name>`

Cause the named pane to have focus. select_ commands must be the last
things run in the script to be effective. (Wrapper around `tmux
select-window`)

`splith [<options>]`

Split the current window horizontally. Any options will be passed to
the tmux `split-window` command. (Wrapper around `tmux split -h`)

`splitv [<options>]`

Split the current window vertically. Any options will be passed to
the tmux `split-window` command. (Wrapper around `tmux split -v`)

Init Script
----------

If you source 'tm-init.sh' in your bash or zshrc startup, this script
will look for ~/.tmux/init/*session name* and if it exists, source
it. This allows every shell started in a session to run some common
initialization code to, e.g., change the working directory, set up the
environment, run a command.

You probably want to source this file late in your shell
initialization after your PATH and other configuration is complete.

'tm-init.sh' also provides some functions for use in a shell running
in tmux:

`tmux_session_name`

Prints the name of the tmux session containing the shell.

`tmux_window_name`

Prints the name of the tmux window containing the shell.

`tmux_pane_title`

Prints the name of the tmux pane containing the shell.

`tmux_set_pane_title <new title>`

Sets the title of the tmux pane containing the shell.

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

If `~/.tmux/tmrc` exists it will be sourced by tm. tmrc can define
functions that can be called in session scripts or set other
environment variables.

The variable *TMUX_ARGS* may be set to specify arguments to be passed
to tmux when called.

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
