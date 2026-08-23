# Arch Post-Install

A personal Arch Linux post-install and dotfiles repo. It automates package installs, symlinks configs into place, and captures GNOME theme/extension state for easy rebuilds.

## Quick Start
- Full setup: `./bootstrap.sh`
- Symlink configs only: `./setup.sh`
- Unified CLI: `./scripts/archpostinstall.sh --help` (or `archpostinstall --help` after linking)

## Repository Layout
- `configs/` tracked configs for shells, editors, terminals, DE/IMEs, and tools.
- `scripts/` grouped by purpose: `install/`, `backup/`, `gnome/`.
- `docs/` reference notes and mappings (`docs/README.md` is the entry point).
- `backups/` archive output (ignored in Git).

## Notes
- Pacman hook updates `scripts/pkglist.txt` automatically after transactions.
- GNOME sync writes extension/theme notes into `docs/` and archives assets into `backups/gnome/`.
- DPMS automation is configured in `configs/archpostinstall/dpms.conf` with a small helper DSL and is controlled through `dpms-toggle`.
- The Omarchy-inspired GNOME screensaver uses custom ASCII art, TerminalTextEffects, `Super+F11`, and a Mutter idle monitor; see `docs/screensaver.md`.
- Secrets are not tracked: copy `configs/baidupcs/pcs_config.json.example` to `configs/baidupcs/pcs_config.json` locally.
- `configs/rime/user.yaml` is ignored because it changes with typing.
