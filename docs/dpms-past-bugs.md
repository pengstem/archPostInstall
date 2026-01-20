# DPMS Past Bug List

- Lock fallback after `flock` can run concurrently if `ps` misses the other instance; treat a busy `flock` as authoritative.
- `set -e` exits after `set_dpms_mode` failure, which can leave apps closed without a `dpms.state` to restore.
- Defaults duplicated between `scripts/gnome/dpms-toggle.sh` and `configs/archpostinstall/dpms.conf` can drift and cause array length errors.
