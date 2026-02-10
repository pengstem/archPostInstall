# Bug History

This file tracks notable configuration issues, their root causes, and the fixes applied.

## 2026-02-05
- Alacritty (GNOME Wayland): background became opaque after setting `startup_mode = "Fullscreen"`.
  Fix: change `startup_mode` to `Maximized` (or `Windowed`) in `configs/alacritty/alacritty.toml`.
- Zellij: F7 keybind failed because `bunx` was missing.
  Fix: prefer `bunx` if available, otherwise fall back to `npx` in `configs/zellij/config.kdl`.
