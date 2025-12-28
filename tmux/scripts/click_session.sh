#!/bin/bash

MOUSE_X=$1

if [ -z "$MOUSE_X" ]; then
    exit 0
fi

# Reconstruct the logic from session_list.sh to determine widths
items=$(tmux list-sessions -F "#{session_created} #{session_name}" | sort -n)

current_x=0

IFS=$'\n'
for item in $items; do
    name=$(echo "$item" | awk '{print $2}')
    
    # Calculate visible length of this item
    # In session_list.sh: " $name " (Space + Name + Space)
    # Length = 1 + length(name) + 1
    len=$((${#name} + 2))
    
    # Check if the click falls within this item's range
    # Range is [current_x, current_x + len)
    if [ "$MOUSE_X" -ge "$current_x" ] && [ "$MOUSE_X" -lt "$((current_x + len))" ]; then
        tmux switch-client -t "$name"
        tmux refresh-client -S
        exit 0
    fi
    
    current_x=$((current_x + len))
done
