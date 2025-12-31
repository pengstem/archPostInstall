# Repository Guidelines

## Project Structure & Module Organization
- `bootstrap.sh` orchestrates the full post-install flow.
- `setup.sh` symlinks tracked configs into user and system locations.
- `configs/` stores dotfiles and application configs (zsh, git, kitty, ghostty, nvim, zed, tmux, fcitx5/rime, pacman/paru, desktop entries).
- `scripts/` contains install and backup/restore utilities; `scripts/pkglist.txt` is the package source of truth.
- Markdown notes like `gnome-appearrance.md`, `gnome-extensions.md`, and `thoughts.md` are reference docs.

## Build, Test, and Development Commands
- `./bootstrap.sh` runs the full setup (packages, shell tools, symlinks, default shell). Requires sudo.
- `./setup.sh` only creates/updates symlinks for dotfiles.
- `./scripts/install_packages.sh` installs packages from `scripts/pkglist.txt` via paru/yay/pacman.
- `./scripts/install_shell_tools.sh` installs or updates Oh My Zsh, plugins, and powerlevel10k.
- `./scripts/backup_firefox.sh` and `./scripts/restore_firefox.sh` manage `~/.mozilla` backups.
- `./scripts/backup_themes_extensions.sh` and `./scripts/restore_themes_extensions.sh` handle themes, icons, and GNOME extensions.

## Coding Style & Naming Conventions
- Bash scripts use `#!/bin/bash`; keep `set -e` in scripts that should fail fast.
- Indent with 4 spaces in shell scripts; use lower_snake_case for functions and UPPER_SNAKE_CASE for constants.
- Keep configs under `configs/<tool>/...` mirroring target paths (see `fileLocationList.md`).
- Use `.desktop` naming for application launchers in `configs/applications/`.

## Testing Guidelines
- No automated test suite. Validate changes by running scripts in a safe environment (VM or fresh install) and verifying symlinks and config targets.
- For script-only edits, run `bash -n <script>` locally to check syntax before execution.

## Commit & Pull Request Guidelines
- History mostly uses Conventional Commit prefixes (`feat:`, `fix:`, `chore:`), with occasional freeform messages. Prefer the prefix style and keep subjects short and imperative.
- PRs should include a brief summary, affected scripts/configs, and manual verification steps (for example, "ran ./setup.sh" or "updated pkglist.txt").

## Security & Configuration Tips
- `setup.sh` writes to `/etc` for `pacman.conf` and `paru.conf`; review diffs before running.
- Backup existing dotfiles when testing changes; the scripts already create timestamped backups for symlink targets.
