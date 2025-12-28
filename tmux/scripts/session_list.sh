#!/bin/bash

# Fetch sessions: Created Time, Name, IsAttached
# Sort numerically by Created Time
items=$(tmux list-sessions -F "#{session_created} #{session_name} #{?session_attached,1,0}" 2>/dev/null | sort -n)

output=""

IFS=$'\n'
for item in $items; do
    # Extract name (field 2) and attached status (field 3)
    name=$(echo "$item" | awk '{print $2}')
    is_active=$(echo "$item" | awk '{print $3}')
    
    if [ "$is_active" == "1" ]; then
        # Active Session: Cyan background, Dark text, Bold
        output="${output}#[fg=#1d1f21,bg=#8abeb7,bold] $name #[default]"
    else
        # Inactive Session: Cyan text, Default background
        output="${output}#[fg=#8abeb7,bg=default] $name #[default]"
    fi
done

echo "$output"