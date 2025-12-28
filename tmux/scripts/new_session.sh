#!/bin/bash

# Calculate count + 1
count=$(tmux list-sessions | wc -l)
sn=$((count + 1))

# Check for collision and increment if necessary
while tmux has-session -t "$sn" 2>/dev/null; do
    sn=$((sn + 1))
done

tmux new-session -d -s "$sn"
tmux switch-client -t "$sn"
