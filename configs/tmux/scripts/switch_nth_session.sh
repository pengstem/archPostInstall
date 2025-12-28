#!/bin/bash

N=$1

if [ -z "$N" ]; then
    exit 1
fi

# Get the target session ID of the Nth session (sorted by creation time)
target=$(tmux list-sessions -F "#{session_created} #{session_id}" 2>/dev/null | sort -n | sed -n "${N}p" | cut -d " " -f2)

if [ -n "$target" ]; then
    tmux switch-client -t "$target"
    tmux refresh-client -S
fi
