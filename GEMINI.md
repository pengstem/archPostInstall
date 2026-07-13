# Arch Post-Install Context

This repository contains a personal Arch Linux post-installation setup and dotfiles management system. It automates package installation, configuration linking, and environment maintenance (GNOME, Firefox, etc.).

## Project Overview

*   **Purpose:** Automate the setup of a personalized Arch Linux environment.
*   **Core Mechanism:** Shell scripts (`bash`) for installation and symlinking.
*   **Package Management:** Tracks installed packages in `scripts/pkglist.txt`, auto-updated via a Pacman hook.
*   **Configuration:** Centralized `configs/` directory symlinked to system/user locations.

## Directory Structure

*   `configs/`: Source of truth for configuration files (Shell, Editors, Terminals, DE/IMEs, Systemd).
*   `scripts/`: Automation scripts.
    *   `install/`: Package and tool installation.
    *   `gnome/`: GNOME state backup and DPMS management.
    *   `backup/`: Firefox and theme backup/restore.
    *   `archpostinstall.sh`: Unified CLI for managing the environment.
*   `docs/`: Documentation and auto-generated reports (GNOME state).
*   `backups/`: ignored directory for storing generated backups.

## Key Workflows & Usage

### 1. Initial Setup
*   **Full Bootstrap:** `./bootstrap.sh`
    *   Installs packages from `scripts/pkglist.txt`.
    *   Sets up shell environment (Zsh, Oh My Zsh, Powerlevel10k).
    *   Invokes `./setup.sh` to link dotfiles.
*   **Config Linking Only:** `./setup.sh`
    *   Safely symlinks files from `configs/` to `$HOME` and `/etc`.
    *   Backs up existing files before overwriting.

### 2. Routine Maintenance (CLI)
The project includes a unified CLI tool linked to `archpostinstall`.
*   **Usage:** `archpostinstall [command]` (or directly via `./scripts/archpostinstall.sh`)
*   **Common Commands:**
    *   `sync`: Backup GNOME state and Firefox.
    *   `update`: Update package list manually.

### 3. Automation Features
*   **Package List Sync:** A pacman hook (`99-update-pkglist.hook`) automatically updates `scripts/pkglist.txt` after every `pacman` transaction.
*   **GNOME Sync:** A systemd user service (`archpostinstall-gnome-sync`) monitors and backs up GNOME extensions and theme settings to `docs/` and `backups/`.
*   **DPMS Automation:** `dpms-toggle` manages display power and app stop/start (configured in the `configs/archpostinstall/dpms.conf` helper DSL).

## Configuration Details

*   **Shell:** Zsh with Powerlevel10k (`configs/p10k.zsh`, `configs/zshrc`).
*   **Editors:** Neovim (`configs/nvim`), Zed (`configs/zed`).
*   **Terminals:** Kitty (`configs/kitty`), Ghostty (`configs/ghostty`), Tmux (`configs/tmux`).
*   **Input Method:** Fcitx5 with Rime (`configs/rime` & `configs/fcitx5`).
*   **Secrets:** Sensitive configs (e.g., `configs/baidupcs/pcs_config.json`) are **not** tracked. Use `.example` files as templates.

## Development & Contribution

*   **Editing Configs:** Edit files directly in `configs/`. Changes are immediate due to symlinks.
*   **Adding Packages:** Install via `pacman`/`paru`. The hook will update `pkglist.txt`.
*   **Documentation:** Refer to `docs/README.md` for detailed mapping of files and features.
