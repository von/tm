tm
==========

tm is a program for running tmux commands. For the latest version, please see
its github page: https://github.com/von/tm

tm does the following:

1) Allows scripted starts of sessions like [tmuxinator][] or
[teamocil][]

2) Allows for the scripts creation of new windows or panes.

3) Starts the tmux server if it isn't running.

4) Allows for the running of a tmux command if run unattached.

5) Allows for a command that if it succeed, skips the rest of the
command script, so if a session exists and can be switched to, its creation is
skipped.

tm uses augmented tmux source files for all of its command. These
are standard tmux source files that contain conditional commands
in the comments that are interpreted by the tm script.

Unlike tmux, tm can be used inside of a tmux session, allowing it to
be used to switch or create sessions from the command-line easily.

Usage
----------

    tm [<options>] [<command name>]

If `command name` is not provided, the contents of the
`$TM_DEFAULT_CMD` environment variable is used; if that variable is
not set, the command `default` is used.

The following options are also supported:

 * `-h` Print help and exit.

 * `-V` Print tm version number and exit.

 * `-d` Run in debug mode.

 * `-v` Run in verbose mode.

 * `-k` Kill the given session. This is equivalent to `tmux kill-session
-t <session name>`.

 * `-K` Kill the tmux server and exit.

 * `-l` List all running sessions and exit. This is equivalent to
'tmux list-sessions'.

 * `-ls` List all available command files. This is intended for use with
auto-completion.

 * `-S` Start the tmux server.

The `command name` can be one of two forms:

1) If it contains a slash, it will be treated as an absolute or relative path
to a file to be used.

2) Otherwise, it should be a file in the path specified by `$TM_CMD_PATH` if
set or `~/.tmux/tm/` otherwise.

Command Files
----------

Command files should be files suitable for use with `tmux source-file`
with the following special commands (that are comments as far as tmux is
concerned):

 * `#@tm-attach: <tmux command>` If the command is run whn not attached to a
tmux session the given `tmux command` will be executed.

 * `#@tm-if-not: <tmux command>` If present, `tmux command` is executed and if
it succeeds (returns zero) then the rest of the command script is not run. This
allows for trying to switch to a session before creating it.

Init Script
----------

If you source `tm-init.sh` in your bash or zshrc startup, this script
will look for `~/.tmux/init/*window name*` or `~/.tmux/init/*session name*` in
that order, and if either exists, source it. This allows every shell started in
a window or session to run some common initialization code to, e.g., change the
working directory, set up the environment, run a command.

You probably want to source this file late in your shell
initialization after your PATH and other configuration is complete.

`tm-init.sh` also provides some functions for use in a shell running
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

    # Switch to or create session "default"
    #
    # If we're not attached, try attaching to "default"
    #@tm-attach: new-session -t default
    #
    # Try switching to session, if this succeeds, then we'rd done.
    #@tm-if-not: switch-client -t default
    #
    # Create session "default" and initial windows
    new-session -s default -n default
    split-window -h
    # Use send-keys so we run reattach-to-user-namespace
    new-window -n vifm
    send-keys "vifm" "Enter"
    new-window -n tasks
    send-keys "vit" "Enter"
    # Select initial pane in initial window
    select-window -t default:default
    select-pane -t 0

Attaching
----------

If tm is run when not attached to a tmux session it will try to
attach. By default it will run `tmux attach` but a more specific
command can be specified using `#@tm-attach:` in a command file.

Starting the tmux server
--------

If tm is run and a tmux server isn't running, it will start one.
A session will be created as part of this process with the name
`tm-session`. This can be overridden by the enironment variable
`$TM_START_SESSION_NAME`.

~/.tmux/tmrc
------

If `~/.tmux/tmrc` exists it will be sourced by tm. This can be
used to override the following tm variables:

    # Path to tm command files
    TM_CMD_PATH=${TM_CMD_PATH:-${HOME}/.tmux/tm}

    # Default tm command if none given
    TM_DEFAULT_CMD="default"

    # Session and window name to use if starting tmux server
    TM_START_WINDOW_NAME=${TM_START_WINDOW_NAME:-tm-window}
    TM_START_SESSION_NAME=${TM_START_SESSION_NAME:-tm-session}

    # tmux binary name
    TMUX_CMD=${TMUX_CMD:-"tmux"}

    # tmux arguments
    TMUX_ARGS=${TMUX_ARGS:-""}

Bash Auto-Completion
------

If you source `bash_completion.sh` you will get auto-completion with
bash. That is, `tm <tab>` will list both all running sessions you can
attach to and all sessions that tm knows about based on start up scripts.

ZSH Auto-Completion
------

The file `_tm` provides autocompletion for zsh. To utilize it, place
the file in a directory which is included in your `fpath`,
e.g. assuming `_tm` is in `~/tm/`:

    fpath=( ~/tm/ $path)

[teamocil]: https://github.com/remiprev/teamocil

[tmuxinator]: https://github.com/aziz/tmuxinator/
