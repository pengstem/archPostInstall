# Zellij Customizations

This folder contains my Zellij configuration and layouts.

## What was added

### 1) Alt + number switches directly to tab
Global keybinds (all modes except locked):
- `Alt 1` .. `Alt 9` → jump to tab 1..9

### 2) Move status into a single top bar
A custom layout (`compact-top`) puts a single compact bar at the top and removes the bottom status bar.

### 3) Easier session switching
Global keybind:
- `Alt s` opens the session manager popup
  - Inside session-manager, `Ctrl r` renames the selected session

## Files touched / added

- `config.kdl`
  - Added `Alt 1..9` and `Alt s` keybinds
  - Set default layout to `compact-top`
  - Set `layout_dir` to `~/.config/zellij/layouts`
- `layouts/compact-top.kdl`

## Restart needed

Zellij reads layout config on startup. Please restart Zellij (or start a new session) after changes.
