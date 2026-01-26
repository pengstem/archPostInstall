# Zellij Customizations

This folder contains my Zellij configuration plus a small plugin to improve tab/session workflows.

## What was added

### 1) Alt + number switches directly to tab
Global keybinds (all modes except locked):
- `Alt 1` .. `Alt 9` → jump to tab 1..9

### 2) Auto-renumber tabs after close
A custom plugin renames tabs to match their current position.
- Default in this repo: always rename to `1 2 3 ...` (so you never see `Tab #...`)
- Optional: preserve custom names by setting `only_numeric "true"`
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

The plugin renames tabs by **position**.
- It listens to `TabUpdate`
- It also runs on a short timer as a fallback (eg. to fix startup / plugin-cache weirdness)

Configuration in `config.kdl`:
```
load_plugins {
    tab-renumber {
        only_numeric "false"  // set to "true" to preserve custom names
        tick_seconds "0.2"    // optional
        // max_tabs "30"      // optional
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
