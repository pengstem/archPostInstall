#!/bin/bash

# Only proceed if session '0' exists
if tmux has-session -t 0 2>/dev/null; then
    # Find the current highest numeric session name
    # We look for purely numeric names, sort them numerically, and take the last one.
    sn=$(tmux list-sessions -F "#{session_name}" | grep -E "^[0-9]+$" | sort -n | tail -n 1)

    # If no numeric sessions exist (other than potentially 0, which we are renaming), start at 1.
    # If 0 is the only one, grep might return 0.
    if [ -z "$sn" ] || [ "$sn" == "0" ]; then
        sn=1
    else
        sn=$((sn + 1))
    fi

    # Ensure we don't overwrite an existing session (though logic above tries to avoid it)
    while tmux has-session -t "$sn" 2>/dev/null; do
        sn=$((sn + 1))
    done

    tmux rename-session -t 0 "$sn"
fi
