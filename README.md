# Arch Post-Install

A personal Arch Linux post-install and dotfiles repo. It automates package installs, installs configs from `manifest.tsv`, and captures GNOME theme/extension state for easy rebuilds.

## Quick Start
- Initialize Rime upstream after cloning: `git submodule update --init -- vendor/rime-frost` (also handled by `setup.sh`).
- Full setup: `./bootstrap.sh`
- Install configs only: `./setup.sh` (`--dry-run` to preview)
- Health check: `archpostinstall doctor`; lint: `archpostinstall lint`
- Unified CLI: `./scripts/archpostinstall.sh --help` (or `archpostinstall --help` after linking)

## Repository Layout
- `configs/` tracked configs for shells, editors, terminals, DE/IMEs, and tools.
- `vendor/` pinned third-party code (rime-frost, thumbfast, uosc); see [vendor/README.md](vendor/README.md). Update with `archpostinstall update-vendor`.
- `manifest.tsv` every source-to-target mapping; user configs are symlinked, root-read files are copied.
- `scripts/` grouped by purpose: `install/`, `backup/`, `gnome/`; package lists in `scripts/pkglist/`.
- `docs/` reference notes and mappings (`docs/README.md` is the entry point).
- `backups/` archive output (ignored in Git).

## Notes
- Pacman hook updates `scripts/pkglist/{native,aur}.txt` after transactions; `hw-<host>.txt` is maintained by hand.
- After editing a root-read config (pacman, TLP, mkinitcpio, ...), run `archpostinstall sync-system`.
- GNOME sync writes extension/theme notes into `docs/` and archives assets into `backups/gnome/`.
- DPMS automation is configured in `configs/archpostinstall/dpms.conf` with a small helper DSL and is controlled through `dpms-toggle`.
- The Omarchy-inspired GNOME screensaver uses custom ASCII art, the Rust `ttfx` renderer, `Super+F11`, and a Mutter idle monitor; see `docs/screensaver.md`.
- Secrets are not tracked: copy `configs/baidupcs/pcs_config.json.example` to `configs/baidupcs/pcs_config.json` locally.
- `configs/rime/user.yaml` is ignored because it changes with typing.
