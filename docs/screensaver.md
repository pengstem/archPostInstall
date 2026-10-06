# Omarchy-Inspired GNOME Screensaver

This setup keeps the part that makes Omarchy's screensaver distinctive: a
personal ASCII logo animated by random terminal text effects. It adapts the
launcher and idle handling for GNOME Wayland instead of copying Omarchy's
Hyprland-specific monitor focus and window rules.

## What Runs

- Kitty opens a decoration-free, opaque, full-screen window.
- `ttfx` 0.5.0, the release-optimized Rust port of TerminalTextEffects 0.15.0,
  animates `screensaver.txt` with a curated random effect at 60 FPS.
- Mutter's session D-Bus idle monitor starts it after five minutes and closes
  it on the next keyboard or pointer event.
- The launcher resolves `ttfx` from the system, `~/.local/bin`, or Cargo's user
  bin directory, because GNOME shortcuts do not inherit an interactive Zsh
  `PATH`.
- A two-second launch grace prevents the initiating shortcut's key release and
  window mapping from immediately dismissing the new full-screen window.
- `archpostinstall-screensaver.service` keeps the idle monitor available in the
  GNOME graphical session.
- `Super+F11` toggles it immediately; `Super+F12` remains the separate DPMS
  shortcut.
- DPMS has priority: turning the display off stops an active screensaver, and
  a nonzero Mutter `PowerSaveMode` prevents a new full-screen window from
  starting. Turning the display back on only restarts the idle countdown.

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

Upgrade the Rust renderer to the newest stable upstream tag with:

```bash
archpostinstall screensaver upgrade
```

The normal bootstrap pins the known-good minimum (`ttfx` 0.5.0 at revision
`112ebb31`) but never downgrades a newer installed release. The explicit
upgrade command discovers stable semantic-version tags from the official
repository, builds with Cargo's lock file, and verifies the installed version.

Disable the service and remove only its own shortcut with:

```bash
archpostinstall screensaver uninstall
```

## Customization

- Edit `configs/archpostinstall/screensaver.txt` to change the centered artwork.
- Edit `configs/archpostinstall/screensaver.conf` to change the idle delay,
  font, frame rate, shortcut, or random-effect allowlist.
- The bundled 107x28 composition keeps the original six-line NASTEM wordmark
  at its geometric center, with ten unevenly scattered stock cowsay figures:
  `tux`, `kitty`, `bunny`, `koala`, `default`, `moose`, `elephant`,
  `hellokitty`, `sheep`, and `small`. It fits the 110x30 Kitty grid on the
  2560x1600 built-in display.
- Keep artwork characters single-column. ASCII, block, and box-drawing
  characters work; emoji and many CJK characters do not align correctly in the
  inherited canvas model.

## Local Performance Comparison

Measured on this machine on 2026-08-24 with the repository's 8-line, 55-column
ASCII art, a fixed 200x50 canvas, output redirected to `/dev/null`, and frame
pacing disabled (`--frame-rate 0`). Each animation is the mean of three runs
after one warm-up; startup is the mean of 50 runs after ten warm-ups.

| Workload | Python TTE 0.15.0 | Rust ttfx 0.3.2 | Speedup |
|---|---:|---:|---:|
| CLI startup (`--version`) | 144.3 ms | 1.6 ms | 87.59x |
| `beams` | 14.166 s | 520.6 ms | 27.21x |
| `decrypt` | 1.144 s | 47.3 ms | 24.19x |
| `waves` | 1.335 s | 58.9 ms | 22.68x |
| `rings` | 3.600 s | 164.2 ms | 21.93x |

Across the four actual animation workloads, the local median improvement is
23.44x. Three `/proc` samples of the same `beams` workload showed a median peak
RSS of 380,048 KiB for Python and 218,092 KiB for Rust: 42.61% less memory.
These throughput numbers measure rendering headroom, not how quickly the
visible animation ends at the configured 60 FPS.

### ttfx 0.3.2 to 0.5.0

Measured on this machine on 2026-09-28 (32 threads, `powersave` governor,
`power-saver` profile) with the current 107x28 `screensaver.txt`, the same
fixed 200x50 canvas, `--frame-rate 0`, and output redirected to `/dev/null`.
Each row is the `hyperfine` mean of five runs after one warm-up; startup is the
mean of 50 runs after ten warm-ups. 0.5.0 adds the "fx" engine, which runs
every effect on flat primitives.

| Workload | ttfx 0.3.2 | ttfx 0.5.0 | Speedup |
|---|---:|---:|---:|
| CLI startup (`--version`) | 1.6 ms | 1.5 ms | 1.06x |
| `beams` | 439.9 ms | 16.5 ms | 26.62x |
| `spotlights` | 275.0 ms | 15.4 ms | 17.84x |
| `synthgrid` | 206.9 ms | 12.7 ms | 16.29x |
| `waves` | 108.7 ms | 8.1 ms | 13.39x |
| `binarypath` | 185.4 ms | 15.3 ms | 12.12x |
| `decrypt` | 76.3 ms | 6.9 ms | 11.10x |
| `burn` | 75.8 ms | 8.2 ms | 9.20x |
| `rings` | 392.1 ms | 52.6 ms | 7.46x |
| `laseretch` | 79.2 ms | 11.1 ms | 7.15x |
| `vhstape` | 66.2 ms | 10.7 ms | 6.21x |
| `fireworks` | 80.7 ms | 16.2 ms | 4.97x |
| `rain` | 30.3 ms | 6.2 ms | 4.87x |

Across these twelve effects the median speedup is 10.15x (geometric mean
10.02x). `matrix` and `thunderstorm` are excluded because they run for a fixed
wall-clock time (about 15 s and 12 s) in both versions. With frame pacing off,
0.5.0 uses 118-139% CPU against the wall time, because rendering moves off the
main thread.

At the real screensaver setting (60 FPS, 110x30 grid, median of three runs),
the visible animation length stays the same, but the CPU time drops:

| Effect | CPU 0.3.2 | CPU 0.5.0 | Peak RSS 0.3.2 | Peak RSS 0.5.0 |
|---|---:|---:|---:|---:|
| `beams` | 0.209 s | 0.029 s | 73.0 MiB | 14.2 MiB |
| `rings` | 0.646 s | 0.165 s | 121.1 MiB | 15.9 MiB |
| `spotlights` | 0.207 s | 0.034 s | 14.2 MiB | 19.4 MiB |
| `fireworks` | 0.133 s | 0.057 s | 19.9 MiB | 14.2 MiB |
| `decrypt` | 0.127 s | 0.037 s | 36.3 MiB | 14.2 MiB |

That is roughly 0.2-0.7% of one core per effect instead of 0.6-2.7%. At 200x50
with no frame pacing, peak RSS for `beams` fell from 214.8 MiB to 16.2 MiB.

## Validation Basis

The launcher and benchmark were validated on 2026-08-24. The scattered cowsay
artwork was validated on 2026-09-04 with GNOME Shell 50.4, Kitty 0.48.2, and
`ttfx` 0.3.2 on a 2560x1600 Wayland output at 1.333x scaling (110x30 terminal
cells) and a 3840x2160 output at 1.5x scaling (147x36 terminal cells). On 2026-09-28, every configured effect and
`--random-effect` exited cleanly on `ttfx` 0.5.0 with the launcher's flags.

The implementation was checked against:

- [Omarchy Quattro screensaver manual](https://github.com/basecamp/omarchy/blob/quattro/manual/13-toggles-idle-screensaver.md), which documents per-monitor full-screen terminals, random text effects, and editable ASCII branding.
- [Current Omarchy launcher](https://github.com/basecamp/omarchy/blob/quattro/bin/omarchy-launch-screensaver) and [runner](https://github.com/basecamp/omarchy/blob/quattro/bin/omarchy-screensaver), for the full-screen terminal and centered-canvas behavior.
- [ttfx source and benchmark notes](https://github.com/omacom-io/ttfx), for the parity-tested Rust port, compatible CLI, release build, and upstream performance methodology.
- [ttfx's implementation plan](https://github.com/omacom/ttfx/blob/master/plan.md), which documents the one-code-point-per-cell compatibility model, and [Omarchy issue #9027](https://github.com/omacom/omarchy/issues/9027), which demonstrates real artwork clipping when display scaling leaves fewer terminal columns than the asset expects.
- [The maintained cowsay repository](https://github.com/cowsay-org/cowsay) and [Arch Linux's cowsay 3.8.4-1 package](https://archlinux.org/packages/extra/any/cowsay/), for the stock cowfile figures used by this artwork.
- [TerminalTextEffects installation and CLI](https://pypi.org/project/terminaltexteffects/), for the original 0.15.0 behavior used as the comparison baseline.
- [Kitty invocation reference](https://sw.kovidgoyal.net/kitty/invocation.html), for Wayland app IDs, per-launch config overrides, and `--start-as fullscreen`.
- [GNOME idle monitor API](https://gnome.pages.gitlab.gnome.org/gnome-desktop/html/gnome-desktop3/gnome-desktop3-GnomeIdleMonitor.html), especially the one-shot user-active watch used to dismiss on keyboard or pointer activity.
- [Omarchy customization discussion #3204](https://github.com/basecamp/omarchy/discussions/3204), confirming that replacing the ASCII input preserves the animations, and [Quattro issue #7762](https://github.com/basecamp/omarchy/issues/7762), which records why relying only on terminal key input misses global mouse movement.
