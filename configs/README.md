# Configs Overview

This directory contains tracked configs that are symlinked into place by `setup.sh`.

## Notable Directories
- `mimeapps.list` user-level default application and MIME associations
- `applications/` user `.desktop` launchers
- `alacritty/` Alacritty terminal config
- `archpostinstall/` helper configs (dpms automation)
- `baidupcs/` BaiduPCS-Go template; real `pcs_config.json` is ignored
- `bottom/`, `btop/` system monitor configs
- `lazygit/` lazygit terminal UI config
- `fcitx5/` input method config
- `ghostty/`, `kitty/`, `wezterm/`, `fastfetch/`, `mpv/`, `zathura/` terminal and media/reader configs
- `nvim/`, `zed/` editor configs
- `obs-studio/` OBS Studio profiles and scene collections
- `rime/` schema and dictionaries (live `user.yaml` is ignored)
- `tmux/` tmux config and helper scripts
- `zellij/` zellij config and layouts
- `zsh/` modular Zsh snippets loaded by `zshrc`
- `xdg-desktop-portal/`, `xdg-desktop-portal-termfilechooser/` portal configs
- `pacman/` and `paru/` system package manager configs
- `systemd/user/` user units (GNOME sync)

## Notes
- System files under `pacman/` and hooks require sudo to link.
- Keep secrets out of tracked files; use `.example` templates when needed.
