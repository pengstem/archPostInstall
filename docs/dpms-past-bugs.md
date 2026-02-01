# DPMS Past Bug List

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

- `zen` shutdown relies on `pkill` matching the correct process name; a mismatch can leave the browser running or force-kill the wrong process.
  **Note:** This is a configuration issue, not a code bug. Users should verify their `DPMS_KILL_MATCHES` patterns match actual process names.

## Refactoring Notes

- Created `dpms-common.sh` shared library with common functions
- Consolidated `is_running_match()` and `list_running_match()` into `find_running_match()`
- Removed duplicate `require_cmd()` and `get_session_id()` functions
- Updated `dpms-lock-monitor.sh` and `cleanup_dpms_logs.sh` to use shared library
