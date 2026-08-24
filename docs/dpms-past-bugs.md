# DPMS Past Bug List

## Screensaver Coordination (2026-08-24)

- Made manual DPMS-off authoritative over the animated screensaver: after the
  Mutter display-power write succeeds, `dpms-toggle.sh` stops any active
  screensaver before continuing with configured app shutdown.
- Added a `PowerSaveMode` guard before the screensaver creates Kitty, inside
  the Kitty runner, and after runner registration. The final check closes the
  race where DPMS-off lands between the initial check and asynchronous window
  creation.
- DPMS-on intentionally does not launch the screensaver. Its shortcut input
  fires Mutter's user-active watch, which stops any stale runner and rearms the
  five-minute idle watch.
- Validated against Mutter 50.4 and gnome-settings-daemon 50.1 source on
  2026-08-24. Mutter's native backend disables the KMS device for every
  nonzero power-save mode; the idle monitor only fires the active transition
  on user activity. Local validation used a mocked `busctl` off-state so no
  physical output had to be powered down.

## Removal Pass (2026-07-13)

- Removed file-based DPMS logging and rotation; messages now go to stderr and are
  available through the systemd journal when launched by a unit.
- Removed the lock/unlock monitor script and user service. DPMS is now explicit
  `--on`, `--off`, or `--toggle` control only.
- Removed the TLP measurement script, its DPMS TLP helpers, and the measurement-only
  sudoers rule. The standalone TLP configuration remains available.
- Validation references used on 2026-07-13:
  - [systemd `journalctl` documentation](https://www.freedesktop.org/software/systemd/man/255/journalctl.html),
    confirming that output from systemd units is connected to the journal.
  - [GNOME community guidance on `LockedHint`](https://discourse.gnome.org/t/monitor-session-unlock-from-sandboxed-application/28155),
    confirming the removed monitor's logind integration was only needed for automatic lock/unlock behavior.

## Simplification Pass (2026-07-13)

- Replaced the unused `running`/`always`/`on_only` policy and reopen-state file with
  explicit `restart`, `start`, and `stop` app actions.
- Removed custom stop commands, the reopen delay, duplicate display-state short-circuits,
  and the non-`flock` lock-directory fallback from the DPMS path.
- Display power is now set first; apps are changed only after the corresponding display
  operation succeeds. Existing logging and start/stop timeouts remain for diagnosis and
  slow GUI applications.
- Validation references used on 2026-07-13:
  - [GNOME Mutter `MetaMonitorManager` documentation](https://mutter.gnome.org/meta/class.MonitorManager.html),
    for the `org.gnome.Mutter.DisplayConfig` service and power-save state.
  - [Linux `pgrep`/`pkill` manual](https://man7.org/linux/man-pages/man1/pgrep.1.html),
    for full-command-line matching and signal behavior.
  - [GNOME community reference](https://discourse.gnome.org/t/how-to-make-kiosk-sessions-screen-go-blank/32548),
    confirming the GNOME Wayland `PowerSaveMode` values used here.

## Cleanup Pass (2026-06-08)

- Removed the unused power-backend resolver and its stale `--power-backend` / `--switch-power` config parsing from `dpms-common.sh`.
- Kept the TLP profile helpers and `--profile-*` defaults because `scripts/power/measure_tlp_power.sh` still uses them.
- Removed thin one-line wrappers from the DPMS path: `dpms-lock-monitor.sh` now calls `dpms_log` directly, and `dpms-toggle.sh` parses app records locally instead of using global side-effect reader helpers.
- Validation references used on 2026-06-08:
  - GNU Bash Reference Manual, fetched 2026-06-08; local Bash version 5.3.12.
  - ShellCheck SC2190 documentation, fetched 2026-06-08; local ShellCheck version 0.11.0.

## Behavior Change (2026-04-28)

- Removed power profile switching from `dpms-toggle.sh`; the DPMS path now only turns the display off/on and manages configured apps.
- Removed `--power-backend`, `--profile-on`, `--profile-off`, `--profile-off-ssh`, `--switch-power`, and `--tlp-use-sudo` from the tracked `dpms.conf` defaults.
- Kept TLP helper functions in `dpms-common.sh` because `scripts/power/measure_tlp_power.sh` still uses them for explicit measurements.
- Validation references used on 2026-04-28:
  - power-profiles-daemon D-Bus API reference: profile switching is exposed through `org.freedesktop.UPower.PowerProfiles` for OS/desktop environment power profile control.
  - ArchWiki TLP / power management notes, fetched 2026-04-28 (Power management revision 870839 / last edited 2026-04-10): power policy is handled by dedicated userspace tools and desktop power components.

## Simplification Pass (2026-03-26)

- Replaced the parallel-array config with `dpms_app` entries and explicit actions.
- Collapsed the old multi-branch DPMS state machine into a linear off/on flow.
- Removed brightness restore, generic GUI sweeping, app activation commands, suspend-on-lock, and the log cleanup timer/service.
- Runtime state is now a plain-text reopen queue instead of sourced shell variables.

## Fixed Bugs (2026-02-01)

- ~~Lock fallback after `flock` can run concurrently if `ps` misses the other instance; treat a busy `flock` as authoritative.~~
  **Fixed:** Removed fallback logic; `flock` is now treated as authoritative. If `flock` fails, script exits immediately.

- ~~`set -e` exits after `set_dpms_mode` failure, which can leave apps closed without a `dpms.state` to restore.~~
  **Fixed:** State is now saved BEFORE attempting DPMS mode change. If `set_dpms_mode` fails, state file exists for recovery.

- ~~Defaults duplicated between `scripts/gnome/dpms-toggle.sh` and `configs/archpostinstall/dpms.conf` can drift and cause array length errors.~~
  **Fixed:** Removed array defaults from script. Arrays are now declared empty and config file is required.

- ~~`grep -v "^$$$"` escaping error in lock fallback code.~~
  **Fixed:** Removed along with the fallback logic in Bug #1 fix.

## Known Issues (Not Fixed)

- `zen` shutdown still relies on the configured `--match` regex catching the right process name; a mismatch can leave the browser running or force-kill the wrong process.
  **Note:** This is a configuration issue, not a code bug. Users should verify their `dpms_app --match ...` regex matches the actual process name.

## Refactoring Notes

- Created `dpms-common.sh` shared library with common functions
- Removed duplicate `require_cmd()` and `get_session_id()` functions
- Updated `dpms-lock-monitor.sh` to use shared library
