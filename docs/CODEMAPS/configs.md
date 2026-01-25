# Configs Codemap

> Generated: 2026-01-23

## Directory Structure

```
configs/
├── archpostinstall/    # DPMS config
├── applications/       # Desktop entries (QQ, WeChat)
├── baidupcs/          # BaiduPCS (optional, needs manual setup)
├── fcitx5/            # Input method
├── ghostty/           # Terminal
├── gitconfig          # Git config
├── kitty/             # Terminal
├── mbsyncrc           # isync/mbsync config
├── mpv/               # Media player
├── msmtprc            # msmtp config
├── neomutt/           # Email client
├── nvim/              # Neovim
├── p10k.zsh           # Powerlevel10k theme
├── pacman/            # System: pacman.conf + hooks
├── paru/              # System: paru.conf
├── rime/              # Input method (some files ignored)
├── sudoers.d/         # System: sudo rules
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
└── zshrc              # Zsh config
```

## Symlink Targets

### User Space (~/.config/ or ~/.)
| Source | Target |
|--------|--------|
| `zshrc` | `~/.zshrc` |
| `p10k.zsh` | `~/.p10k.zsh` |
| `gitconfig` | `~/.gitconfig` |
| `kitty/` | `~/.config/kitty/` |
| `ghostty/` | `~/.config/ghostty/` |
| `wezterm/` | `~/.config/wezterm/` |
| `nvim/` | `~/.config/nvim/` |
| `zed/` | `~/.config/zed/` |
| `tmux/` | `~/.config/tmux/` |
| `zellij/` | `~/.config/zellij/` |
| `yazi/` | `~/.config/yazi/` |
| `zathura/` | `~/.config/zathura/` |
| `mpv/` | `~/.config/mpv/` |
| `neomutt/` | `~/.config/neomutt/` |
| `mbsyncrc` | `~/.mbsyncrc` |
| `msmtprc` | `~/.msmtprc` |
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
| `sudoers.d/archpostinstall-tlp` | `/etc/sudoers.d/` |

## Key Config Files

### dpms.conf
```bash
# App management (parallel arrays)
APPS_TO_KILL=("app1" "app2")
KILL_PATTERNS=("pattern1" "pattern2")
REOPEN_COMMANDS=("cmd1" "cmd2")
WM_CLASSES=("class1" "class2")

# Power profiles
POWER_PROFILE_ON="balanced"
POWER_PROFILE_OFF="power-saver"

# Idle settings
IDLE_TIMEOUT_MINUTES=15
SKIP_WHEN_PLAYING_MEDIA=true

# Logging
LOG_VERBOSE=1
LOG_MAX_SIZE_MB=1
```

### Systemd Units
- `archpostinstall-gnome-sync.{path,service}` - Watch GNOME config changes
- `archpostinstall-dpms-idle.{timer,service}` - 60s idle check
- `archpostinstall-dpms-restore.{timer,service}` - 45s restore check
- `archpostinstall-dpms-log-cleanup.{timer,service}` - Log rotation
