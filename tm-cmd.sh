#!/bin/sh
#
# Wrapper around 'tmux send-keys' to handle sending 'Enter'
tmux send-keys "${*}"
tmux send-keys "Enter"
