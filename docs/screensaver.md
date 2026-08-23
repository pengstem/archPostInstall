# Omarchy-Inspired GNOME Screensaver

This setup keeps the part that makes Omarchy's screensaver distinctive: a
personal ASCII logo animated by random terminal text effects. It adapts the
launcher and idle handling for GNOME Wayland instead of copying Omarchy's
Hyprland-specific monitor focus and window rules.

## What Runs

- Kitty opens a decoration-free, opaque, full-screen window.
- TerminalTextEffects 0.15.0 animates `screensaver.txt` with a curated random
  effect at 60 FPS.
- Mutter's session D-Bus idle monitor starts it after five minutes and closes
  it on the next keyboard or pointer event.
- `archpostinstall-screensaver.service` keeps the idle monitor available in the
  GNOME graphical session.
- `Super+F11` toggles it immediately; `Super+F12` remains the separate DPMS
  shortcut.

This is visual only. It does not authenticate, lock the session, inhibit
GNOME's own lock screen, or change suspend/DPMS policy.

## Commands

```bash
archpostinstall screensaver start
archpostinstall screensaver stop
archpostinstall screensaver toggle
archpostinstall screensaver status
```

`bootstrap.sh` installs the package, links the files, enables the user service,
and registers `Super+F11`. On an existing installation after running
`./setup.sh`, activate it with:

```bash
archpostinstall screensaver install
```

Disable the service and remove only its own shortcut with:

```bash
archpostinstall screensaver uninstall
```

## Customization

- Edit `configs/archpostinstall/screensaver.txt` to change the centered artwork.
- Edit `configs/archpostinstall/screensaver.conf` to change the idle delay,
  font, frame rate, shortcut, or random-effect allowlist.
- Keep artwork characters single-column. Block and box-drawing characters work;
  emoji and many CJK characters do not align correctly in TTE's current canvas
  model.

## Validation Basis

Validated on 2026-08-24 with GNOME Shell 50.4, Kitty 0.48.2,
TerminalTextEffects 0.15.0, one 3840x2400 Wayland output, and the
`python-terminaltexteffects` 0.15.0-1 AUR package metadata.

The implementation was checked against:

- [Omarchy Quattro screensaver manual](https://github.com/basecamp/omarchy/blob/quattro/manual/13-toggles-idle-screensaver.md), which documents per-monitor full-screen terminals, random text effects, and editable ASCII branding.
- [Current Omarchy launcher](https://github.com/basecamp/omarchy/blob/quattro/bin/omarchy-launch-screensaver) and [runner](https://github.com/basecamp/omarchy/blob/quattro/bin/omarchy-screensaver), for the full-screen terminal and centered-canvas behavior.
- [TerminalTextEffects installation and CLI](https://pypi.org/project/terminaltexteffects/), for version 0.15.0 and the random-effect/include-effect options.
- [Kitty invocation reference](https://sw.kovidgoyal.net/kitty/invocation.html), for Wayland app IDs, per-launch config overrides, and `--start-as fullscreen`.
- [GNOME idle monitor API](https://gnome.pages.gitlab.gnome.org/gnome-desktop/html/gnome-desktop3/gnome-desktop3-GnomeIdleMonitor.html), especially the one-shot user-active watch used to dismiss on keyboard or pointer activity.
- [Omarchy customization discussion #3204](https://github.com/basecamp/omarchy/discussions/3204), confirming that replacing the ASCII input preserves the animations, and [Quattro issue #7762](https://github.com/basecamp/omarchy/issues/7762), which records why relying only on terminal key input misses global mouse movement.
