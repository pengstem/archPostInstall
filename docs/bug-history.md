# Bug History

This file tracks notable configuration issues, their root causes, and the fixes applied.

## 2026-02-05
- Alacritty (GNOME Wayland): background became opaque after setting `startup_mode = "Fullscreen"`.
  Fix: change `startup_mode` to `Maximized` (or `Windowed`) in `configs/alacritty/alacritty.toml`.
- Zellij: F7 keybind failed because `bunx` was missing.
  Fix: prefer `bunx` if available, otherwise fall back to `npx` in `configs/zellij/config.kdl`.

## 2026-03-19
- Kitty watermark: the top-right signature looked diagonally tilted and sat slightly too high/left.
  Fix: remove the baked-in SVG rotation, shift the artwork down/right within the canvas, and regenerate `configs/kitty/nastem-signature.png` from the updated source.

## 2026-03-25
- Yazi `g n`: opening GNOME Files from the manager could hand Nautilus a malformed doubled path such as `"/path"/"/path"`.
  Fix: replace the inline nested `shell` snippet with a dedicated launcher script at `scripts/launchers/yazi-open-nautilus.sh`, and wire it through `configs/yazi/keymap.toml` and `setup.sh`.

## 2026-04-08
- Hyde install: it injected `~/.zshenv` and extra dotfiles into the repo-backed `configs/zsh/`, which diverted Zsh away from the repo's modular startup and left the workspace dirty with generated cache files.
  Fix: remove the Hyde-generated Zsh files, move the home-level Hyde leftovers into `~/.config/cfg_backups/*_codex_hyde_cleanup/`, and redirect Zsh history / compdump output to `~/.local/state/zsh/` and `~/.cache/zsh/`.

## 2026-06-08
- GNOME backup pruning: `backup_themes_extensions.sh` used an unquoted glob array and `ls -t` to detect/prune archives, which was fragile and noisy under ShellCheck.
  Fix: use `find` for existence checks and compare mtimes with `stat` before pruning older archives.
