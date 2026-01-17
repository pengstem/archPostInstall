# Configs Overview

This directory contains tracked configs that are symlinked into place by `setup.sh`.

## Notable Directories
- `applications/` user `.desktop` launchers
- `archpostinstall/` helper configs (dpms automation)
- `baidupcs/` BaiduPCS-Go template; real `pcs_config.json` is ignored
- `fcitx5/` input method config
- `ghostty/`, `kitty/`, `wezterm/`, `mpv/`, `zathura/` terminal and media/reader configs
- `nvim/`, `zed/` editor configs
- `rime/` schema and dictionaries (live `user.yaml` is ignored)
- `tmux/` tmux config and helper scripts
- `xdg-desktop-portal/`, `xdg-desktop-portal-termfilechooser/` portal configs
- `pacman/` and `paru/` system package manager configs
- `systemd/user/` user units (GNOME sync)

## Notes
- System files under `pacman/` and hooks require sudo to link.
- Keep secrets out of tracked files; use `.example` templates when needed.
