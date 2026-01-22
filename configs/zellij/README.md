# Zellij Customizations

This folder contains my Zellij configuration plus a small plugin to improve tab/session workflows.

## What was added

### 1) Alt + number switches directly to tab
Global keybinds (all modes except locked):
- `Alt 1` .. `Alt 9` → jump to tab 1..9

### 2) Auto-renumber tabs after close
A custom plugin renames tabs to match their current position **only when the tab name is empty or purely numeric**, so your custom names are preserved.
- Example: after closing tab 2, tabs become `1 2 3 ...`

### 3) Move status into a single top bar
A custom layout (`compact-top`) puts a single compact bar at the top and removes the bottom status bar.

### 4) Easier session switching
Global keybind:
- `Alt s` opens the session manager popup
  - Inside session-manager, `Ctrl r` renames the selected session

## Files touched / added

- `config.kdl`
  - Added `Alt 1..9` and `Alt s` keybinds
  - Added `tab-renumber` plugin alias + auto-load
  - Set default layout to `compact-top`
  - Set `layout_dir` to `~/.config/zellij/layouts`
- `layouts/compact-top.kdl`
- `plugins/auto-tab-rename/`
  - Rust WASI plugin source + build output

## Plugin behavior (auto-tab-rename)

The plugin listens to `TabUpdate` and renames tabs by **position**.
By default it only renames tabs with empty or numeric names.

Configuration in `config.kdl`:
```
load_plugins {
    tab-renumber {
        only_numeric "true"   // change to "false" to always rename
        // prefix "T"          // optional prefix, e.g. T1, T2...
    }
}
```

## Build / rebuild the plugin

If you edit the plugin source:
```
cd /home/nastem/.config/zellij/plugins/auto-tab-rename
cargo build --release --target wasm32-wasip1
```

The compiled WASM is loaded from:
- `plugins/auto-tab-rename/target/wasm32-wasip1/release/auto_tab_rename.wasm`

## Restart needed

Zellij reads layout + plugin config on startup. Please restart Zellij (or start a new session) after changes.
