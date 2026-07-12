# Reinstall recovery checklist

Audit date: 2026-07-12 (Asia/Singapore)

This file records the post-reinstall audit and the actions that still need to be
run in the real GNOME session. It is deliberately separate from the existing
bug-history files because it is a recovery checklist, not a historical bug
entry.

## What was checked

- The host is Arch Linux with GNOME 50.3, pacman 7.1.0.r9, paru 2.1.0, and
  Bash 5.3.15.
- The main home-directory links already point into this checkout, including
  Zsh, Kitty, Neovim, Fcitx5, Rime, the desktop entries, the helper binaries,
  and all three user systemd unit files.
- The system links already point into this checkout for pacman, paru, the
  pacman hook, the package-list updater, DPMS, and the TLP override.
- The Fcitx5/Rime, terminal, media, reader, mail, and OBS configuration trees
  are present in the repository and linked in the home directory.
- `bash -n` validation is clean for the repository Bash scripts. ShellCheck is
  not installed in this environment, so ShellCheck validation was not run.
- `desktop-file-validate` accepts all tracked desktop entries; it reports only
  existing category hints for Yazi. `systemd-analyze verify` could not return a
  trustworthy status because this sandbox rejects the systemd user-socket
  credential operations.
- `configs/baidupcs/pcs_config.json` exists locally and is ignored by Git. Its
  permissions were tightened to `0600` without reading its contents.
- `.gitmodules` was repaired so all three tracked tmux gitlinks can be
  initialized from a fresh clone.
- `configs/applications/ratty.desktop` was corrected to use a valid absolute
  config path; `%h` is not a freedesktop desktop-entry field code.

## Why the remaining setup could not be run here

This execution environment blocks privilege escalation. The exact checks were:

```text
sudo: /etc/sudo.conf is owned by uid 65534, should be 0
sudo: The "no new privileges" flag is set, which prevents sudo from running as root.
```

Therefore I did not run `setup.sh`, install packages, write `/etc/sudoers.d`,
or enable system services from this environment. Those operations need the real
installed system and a normal user session. I also could not query
`systemctl --user` because the user D-Bus is unavailable to this execution
environment.

## Run on the real installed system

Run these as the normal user, from the repository root:

```bash
cd /home/nastem/Project/archPostInstall
sudo -v
./setup.sh
sudo visudo -cf /etc/sudoers.d/archpostinstall-tlp
```

`setup.sh` is idempotent for correctly linked targets. It will install the TLP
sudoers file and refresh system links; it will not create the missing Nowledge
Mem launcher described below.

Then, inside the logged-in GNOME session:

```bash
mkdir -p ~/.local/share/gnome-shell/extensions ~/.themes ~/.local/share/icons
systemctl --user daemon-reload
systemctl --user enable --now archpostinstall-gnome-sync.path
systemctl --user enable --now archpostinstall-dpms-lock-monitor.service
systemctl --user --no-pager status archpostinstall-gnome-sync.path
systemctl --user --no-pager status archpostinstall-dpms-lock-monitor.service
```

If the user bus is not available, log into the graphical GNOME session first;
do not run these commands with `sudo`.

## Packages still missing for tracked configurations

The current `scripts/pkglist.txt` is a fresh, user-generated package snapshot
and is intentionally preserved. It is missing packages for several tracked
configuration trees. The older untracked `scripts/pkglist_1.txt` is not safe to
feed directly to pacman: it contains packages listed in `unwanted_packages.txt`
and also contains the literal `qemu-*` wildcard.

After a normal full upgrade, install the official-repository packages that
correspond to tracked configs:

```bash
sudo pacman -Syu --needed \
  fcitx5 fcitx5-rime fcitx5-configtool fcitx5-gtk fcitx5-qt \
  ghostty mpv tmux zellij zathura zathura-pdf-mupdf \
  obs-studio isync msmtp neomutt bottom wezterm \
  ratty baidupcs-go zed
```

The package names above were verified against the configured Arch repository
metadata on 2026-07-12. The package manager may present a current transaction
plan; review it before accepting. Do not run a package-removal command based on
`unwanted_packages.txt` until each item has been confirmed manually.

The `xdg-desktop-portal-termfilechooser` helper is configured in this repo, but
no package matching either `xdg-desktop-portal-termfilechooser` or the old
`xdg-desktop-portal-termfilechooser-hunkyburrito-git` name was available in the
configured package databases during this audit. Investigate the package/source
name before installing it:

```bash
pacman -Ss termfilechooser
paru -Ss termfilechooser
```

The repo-local `yazi-wrapper.sh` is already linked; the portal backend package
is the unresolved part.

## TLP versus power-profiles-daemon: choice required

The current system has `power-profiles-daemon`, while this repo also contains a
TLP override and TLP sudoers policy. The DPMS script no longer changes power
profiles, so TLP is not needed for DPMS itself. TLP documentation warns that
TLP and `power-profiles-daemon` compete over overlapping settings.

Keep the current GNOME power-profile setup by skipping TLP, or deliberately
choose TLP and follow its conflict guidance. Only if TLP is the intended choice
should you run commands like these after reviewing the transaction:

```bash
sudo pacman -Syu --needed tlp tlp-rdw
sudo systemctl disable --now power-profiles-daemon.service
sudo systemctl enable --now tlp.service
```

Do not run both power managers concurrently. This choice was not made
automatically because it changes the system's power-management policy.

## Items needing a personal decision or files outside this repo

### Nowledge Mem

The tracked `scripts/launchers/nowledge-mem-desktop.sh` is deleted in the
current worktree, while the desktop entry and `setup.sh` still reference it.
I did not restore a user-deleted file. If Nowledge Mem is still wanted, inspect
the old file and restore it deliberately:

```bash
git show HEAD:scripts/launchers/nowledge-mem-desktop.sh
git restore --source=HEAD -- scripts/launchers/nowledge-mem-desktop.sh
chmod +x scripts/launchers/nowledge-mem-desktop.sh
```

The expected AppImage `/home/nastem/Applications/nowledge-mem.AppImage` is
also absent, so the desktop entry cannot work until that application is
restored. `QQ.AppImage` and `WeChat.AppImage` are present and executable, but
their configured user icon files are absent; restore those icons or accept the
generic icon.

OBS is configured to record under `/home/nastem/Videos/obs`; create that
directory if it is not already present:

```bash
mkdir -p ~/Videos/obs
```

### Existing worktree changes

These pre-existing changes were not reverted or included in the recovery fix:

- Most tracked files have a `100644 -> 100755` mode change.
- `scripts/pkglist.txt` was reduced to the current installed snapshot.
- `configs/btop/btop.conf`, `configs/nvim/lazy-lock.json`, and `configs/zshrc`
  contain real content changes.
- The three backup `.gitkeep` files are deleted.
- The nested tmux submodules have local changes.
- `.claude/`, `scripts/pkglist_1.txt`, and `unwanted_packages.txt` are
  untracked.

These may be intentional reinstall work, so they were left untouched. Empty
backup directories will be recreated by the backup scripts when needed. On a
fresh clone, initialize the now-complete submodule metadata with:

```bash
git submodule sync --recursive
git submodule update --init --recursive
```

Do that only after preserving any local changes inside the current nested
submodules.

## References used for this audit

- [ArchWiki: systemd](https://wiki.archlinux.org/title/Systemd) — user-unit
  activation and `enable --now` behavior.
- [ArchWiki: Fcitx5](https://wiki.archlinux.org/title/Fcitx5) — package split,
  Rime/GTK/Qt integration, and Wayland caveats.
- [ArchWiki: Package management FAQs](https://wiki.archlinux.org/index.php/Package_Management_FAQs)
  — full upgrade guidance and restoring package lists.
- [TLP: power-profiles-daemon](https://linrunner.de/tlp/faq/ppd.html) — why
  TLP and `power-profiles-daemon` should not be run together.
- [freedesktop.org Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry/desktop-entry-spec-latest.html)
  — `Exec`, `TryExec`, and icon path behavior.
