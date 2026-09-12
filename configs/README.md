# Configs Overview

This directory contains tracked configs that are symlinked into place by `setup.sh`.

## Notable Directories
- `mimeapps.list` user-level default application and MIME associations
- `applications/` user `.desktop` launchers
- `alacritty/` Alacritty terminal config
- `archpostinstall/` helper configs (DPMS and animated screensaver)
- `baidupcs/` BaiduPCS-Go template; real `pcs_config.json` is ignored
- `bottom/`, `btop/` system monitor configs
- `lazygit/` lazygit terminal UI config
- `fcitx5/` input method config
- `ghostty/`, `kitty/`, `wezterm/`, `fastfetch/`, `mpv/`, `zathura/` terminal and media/reader configs
- `nvim/`, `zed/` editor configs
- `obs-studio/` OBS Studio profiles and scene collections
- `plymouth/`, `mkinitcpio/`, `kernel/` Zen UKI and Connect boot splash configuration
- `rime/` personal patches and links into `vendor/rime-frost/`; see [maintenance instructions](rime/README.md) (live user databases and `user.yaml` are ignored)
- `tmux/` tmux config and helper scripts
- `zellij/` zellij config and layouts
- `zsh/` modular Zsh snippets loaded by `zshrc`
- `xdg-desktop-portal/`, `xdg-desktop-portal-termfilechooser/` portal configs
- `pacman/` and `paru/` system package manager configs
- `systemd/user/` user units (GNOME sync and idle screensaver)

## Notes
- System files under `pacman/`, `plymouth/`, `mkinitcpio/`, and `kernel/` require root privileges to install. Plymouth files are copied to their canonical paths so mkinitcpio archives them correctly; the remaining managed configs are linked.
- Use `archpostinstall boot-splash apply` from a root shell to back up, rebuild, and verify the Zen UKI after linking boot configs.
- Keep secrets out of tracked files; use `.example` templates when needed.
