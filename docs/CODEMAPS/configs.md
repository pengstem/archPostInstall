# Configs Codemap

> Generated: 2026-01-23

## Directory Structure

```
configs/
├── archpostinstall/    # DPMS and screensaver config/art
├── applications/       # Desktop entries (QQ, WeChat, Ratty)
├── baidupcs/          # BaiduPCS (optional, needs manual setup)
├── fcitx5/            # Input method
├── ghostty/           # Terminal
├── gitconfig          # Git config
├── kitty/             # Terminal
├── lazygit/           # Git terminal UI
├── mpv/               # Media player
├── nvim/              # Neovim
├── p10k.zsh           # Powerlevel10k theme
├── pacman/            # System: pacman.conf + hooks
├── paru/              # System: paru.conf
├── ratty/             # Terminal
├── rime/              # Input method (some files ignored)
├── systemd/user/      # User systemd units
├── tlp/               # System: TLP power config
├── tmux/              # Terminal multiplexer
├── wezterm/           # Terminal
├── xdg-desktop-portal/
├── xdg-desktop-portal-termfilechooser/
├── yazi/              # File manager
├── zathura/           # PDF viewer
├── zed/               # Editor
├── zellij/            # Terminal multiplexer
├── zsh/               # Modular Zsh config snippets
└── zshrc              # Zsh config
```

## Symlink Targets

### User Space (~/.config/ or ~/.)
| Source | Target |
|--------|--------|
| `zshrc` | `~/.zshrc` |
| `zsh/` | `~/.config/zsh/` |
| `p10k.zsh` | `~/.p10k.zsh` |
| `gitconfig` | `~/.gitconfig` |
| `kitty/` | `~/.config/kitty/` |
| `lazygit/` | `~/.config/lazygit/` |
| `ratty/` | `~/.config/ratty/` |
| `ghostty/` | `~/.config/ghostty/` |
| `wezterm/` | `~/.config/wezterm/` |
| `nvim/` | `~/.config/nvim/` |
| `zed/` | `~/.config/zed/` |
| `tmux/` | `~/.config/tmux/` |
| `zellij/` | `~/.config/zellij/` |
| `yazi/` | `~/.config/yazi/` |
| `zathura/` | `~/.config/zathura/` |
| `mpv/` | `~/.config/mpv/` |
| `fcitx5/` | `~/.config/fcitx5/` |
| `rime/` | `~/.local/share/fcitx5/rime/` |
| `archpostinstall/` | `~/.config/archpostinstall/` |
| `systemd/user/` | `~/.config/systemd/user/` |
| `applications/*.desktop` | `~/.local/share/applications/` |
| `zathura/page-to-clipboard.sh` | `~/.local/bin/` |

### System (/etc/) - Requires sudo
| Source | Target |
|--------|--------|
| `pacman/pacman.conf` | `/etc/pacman.conf` |
| `paru/paru.conf` | `/etc/paru.conf` |
| `pacman/hooks/*.hook` | `/etc/pacman.d/hooks/` |
| `tlp/99-archpostinstall.conf` | `/etc/tlp.d/` |

## Key Config Files

### dpms.conf
```bash
dpms_app --name zen-browser --match 'zen-bin|zen-browser' --start 'zen-browser'
dpms_app --name steam --match 'steam' --action stop
```

### screensaver.conf / screensaver.txt
- Five-minute idle delay, 60 FPS, Maple Mono NF CN, and a curated TTE effect allowlist
- Custom single-cell-width NASTEM ASCII artwork

### Systemd Units
- `archpostinstall-gnome-sync.{path,service}` - Watch GNOME config changes
- `archpostinstall-screensaver.service` - Watch Mutter idle/activity state
