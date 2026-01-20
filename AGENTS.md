# Repository Guidelines

## Project Structure & Module Organization
- `README.md` is the entry point for setup and layout information.
- `bootstrap.sh` orchestrates the full post-install flow.
- `setup.sh` symlinks tracked configs into user and system locations.
- `configs/` stores dotfiles and application configs (zsh, git, kitty, ghostty, nvim, zed, yazi, zathura, mpv, BaiduPCS-Go, tmux, fcitx5/rime, pacman/paru, TLP, desktop entries, archpostinstall helpers). See `configs/README.md`.
- `scripts/` is split by function: `scripts/install/`, `scripts/backup/`, `scripts/gnome/`, `scripts/power/`; `scripts/pkglist.txt` is the package source of truth.
- `configs/systemd/user/` defines GNOME sync units plus DPMS idle/restore/log-cleanup timers.
- `configs/pacman/hooks/` contains pacman hooks (for example, automatic pkglist updates).
- `docs/` holds reference notes like `gnome-appearrance.md`, `gnome-extensions.md`, and `thoughts.md` (see `docs/README.md` and `docs/commands.md`).
- `docs/dpms-past-bugs.md` tracks DPMS pitfalls; update it when changing DPMS scripts/configs/timers.
- `backups/` is the default archive location for GNOME themes/extensions and Firefox profiles.

## Build, Test, and Development Commands
- `./bootstrap.sh` runs the full setup (packages, shell tools, symlinks, default shell). Requires sudo.
- `./scripts/archpostinstall.sh` provides a unified CLI wrapper for common tasks (see `--help`).
- `./setup.sh` only creates/updates symlinks for dotfiles.
- `./scripts/install/install_packages.sh` installs packages from `scripts/pkglist.txt` via paru/yay/pacman.
- `./scripts/install/install_shell_tools.sh` installs or updates Oh My Zsh, plugins, and powerlevel10k.
- `./scripts/backup/backup_firefox.sh` and `./scripts/backup/restore_firefox.sh` manage `~/.mozilla` backups (default `backups/firefox/`).
- `./scripts/backup/backup_themes_extensions.sh` and `./scripts/backup/restore_themes_extensions.sh` handle themes, icons, and GNOME extensions (default `backups/gnome/`).
- `./scripts/gnome/backup_gnome_state.sh` refreshes GNOME extension/theme notes and archives assets (used by the systemd path unit).
- `./scripts/gnome/dpms-toggle.sh` toggles display power, manages autostart apps, and cooperates with idle/restore timers.
- `./scripts/power/measure_tlp_power.sh` measures average power draw for TLP profiles.

## Coding Style & Naming Conventions
- Bash scripts use `#!/bin/bash`; keep `set -e` in scripts that should fail fast.
- Indent with 4 spaces in shell scripts; use lower_snake_case for functions and UPPER_SNAKE_CASE for constants.
- Keep configs under `configs/<tool>/...` mirroring target paths (see `docs/fileLocationList.md`).
- Use `.desktop` naming for application launchers in `configs/applications/`.

## Testing Guidelines
- No automated test suite. Validate changes by running scripts in a safe environment (VM or fresh install) and verifying symlinks and config targets.
- For script-only edits, run `bash -n <script>` locally to check syntax before execution.

## Commit & Pull Request Guidelines
- History mostly uses Conventional Commit prefixes (`feat:`, `fix:`, `chore:`), with occasional freeform messages. Prefer the prefix style and keep subjects short and imperative.
- Auto-commit: after making changes, stage and commit them without asking; pick the most accurate Conventional Commit prefix and concise subject.
- PRs should include a brief summary, affected scripts/configs, and manual verification steps (for example, "ran ./setup.sh" or "updated pkglist.txt").

## Security & Configuration Tips
- `setup.sh` writes to `/etc` for `pacman.conf` and `paru.conf`; review diffs before running.
- `setup.sh` installs `/etc/tlp.d/99-archpostinstall.conf` and `/etc/sudoers.d/archpostinstall-tlp` for TLP automation.
- Pacman hook calls `/usr/local/bin/archpostinstall-update-pkglist`, linked to `scripts/update_pkglist.sh` by `setup.sh`.
- GNOME sync runs from `~/.local/bin/archpostinstall-gnome-sync`; enable the user unit after linking.
- DPMS automation uses `~/.local/bin/dpms-toggle` plus systemd user timers (`archpostinstall-dpms-idle.timer`, `archpostinstall-dpms-restore.timer`, `archpostinstall-dpms-log-cleanup.timer`).
- `configs/baidupcs/pcs_config.json` is ignored; keep secrets there and use `pcs_config.json.example` as a template.
- `configs/rime/user.yaml` is ignored to avoid churn from live input.
- Backup existing dotfiles when testing changes; the scripts already create timestamped backups for symlink targets.
