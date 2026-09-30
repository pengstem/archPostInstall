#!/usr/bin/python3

"""Display power for dpms-toggle: `hold` keeps it off, `on` turns it back on.

hold  Runs as a systemd user unit (Type=notify) for as long as the display
      should stay off. gnome-settings-daemon unblanks on the first input after
      its idle-dim timeout even though it never blanked, so this holds a
      session idle inhibitor (Mutter then pauses the dim watch) and writes the
      off mode back whenever something else turns the display on (resume,
      gsd re-running idle_configure). gsd answers the new inhibitor with a
      PowerSaveMode=0 write; the display goes off after that write, or after
      SETTLE_MS, and only then is READY=1 sent.

on    Writes PowerSaveMode=0, then checks the display actually lit. On Mutter
      50.5 with the NVIDIA driver it can report 0 while every connector stays
      off; rewriting 0 or cycling through 1 does not help, but re-applying
      the current monitor configuration (temporary method: no confirmation
      dialog, monitors.xml untouched) forces a modeset.

See docs/dpms-past-bugs.md.
"""

from __future__ import annotations

import glob
import os
import socket
import sys
import time

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

ON_MODE = 0
OFF_MODE = 1
INHIBIT_IDLE = 8
SETTLE_MS = 300
LIGHT_TIMEOUT_SEC = 2.0
LIGHT_POLL_SEC = 0.02
CONFIG_METHOD_TEMPORARY = 1
MONITOR_OPTION_KEYS = ("color-mode", "rgb-range")


def log(message: str) -> None:
    print(f"[dpms] {message}", file=sys.stderr, flush=True)


def proxy(name: str, path: str, interface: str) -> Gio.DBusProxy:
    return Gio.DBusProxy.new_for_bus_sync(
        Gio.BusType.SESSION,
        Gio.DBusProxyFlags.DO_NOT_AUTO_START,
        None,
        name,
        path,
        interface,
        None,
    )


def display_config() -> Gio.DBusProxy:
    return proxy(
        "org.gnome.Mutter.DisplayConfig",
        "/org/gnome/Mutter/DisplayConfig",
        "org.gnome.Mutter.DisplayConfig",
    )


def set_mode(display: Gio.DBusProxy, mode: int) -> None:
    display.call_sync(
        "org.freedesktop.DBus.Properties.Set",
        GLib.Variant(
            "(ssv)",
            (display.get_interface_name(), "PowerSaveMode", GLib.Variant("i", mode)),
        ),
        Gio.DBusCallFlags.NONE,
        -1,
        None,
    )


def notify_ready() -> None:
    address = os.environ.get("NOTIFY_SOCKET")
    if not address:
        return
    if address.startswith("@"):
        address = "\0" + address[1:]
    with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as sock:
        sock.connect(address)
        sock.send(b"READY=1")


def hold() -> int:
    display = display_config()
    session = proxy(
        "org.gnome.SessionManager",
        "/org/gnome/SessionManager",
        "org.gnome.SessionManager",
    )
    loop = GLib.MainLoop()
    held = False
    failed = False
    last_mode = display.get_cached_property("PowerSaveMode").unpack()

    def go_dark() -> bool:
        nonlocal held, failed
        if held:
            return GLib.SOURCE_REMOVE
        held = True
        try:
            set_mode(display, OFF_MODE)
        except GLib.Error as error:
            log(f"Error: failed to turn the display off: {error.message}")
            failed = True
            loop.quit()
        else:
            notify_ready()
        return GLib.SOURCE_REMOVE

    def on_properties_changed(_proxy, changed: GLib.Variant, _invalidated) -> None:
        nonlocal last_mode
        mode = changed.lookup_value("PowerSaveMode", None)
        if mode is None:
            return
        # Mutter re-emits same-value writes, so gsd's answer to the inhibitor
        # arrives as a 0 even though the display is already on.
        previous, last_mode = last_mode, mode.unpack()
        if not held:
            if last_mode == ON_MODE:
                go_dark()
        elif last_mode == ON_MODE and previous != ON_MODE:
            log("display was turned on externally; turning it off again")
            set_mode(display, OFF_MODE)

    display.connect("g-properties-changed", on_properties_changed)
    # The inhibitor lasts as long as this bus connection, so stopping the unit
    # releases it; no Uninhibit or signal handling needed.
    try:
        session.call_sync(
            "Inhibit",
            GLib.Variant(
                "(susu)", ("archpostinstall-dpms", 0, "Display turned off", INHIBIT_IDLE)
            ),
            Gio.DBusCallFlags.NONE,
            -1,
            None,
        )
    except GLib.Error as error:
        log(f"idle inhibitor unavailable, relying on the watch: {error.message}")
    GLib.timeout_add(SETTLE_MS, go_dark)
    loop.run()
    return 1 if failed else 0


def lit_connectors() -> int:
    lit = 0
    for path in glob.glob("/sys/class/drm/card*-*/enabled"):
        with open(path, encoding="utf-8") as enabled:
            lit += enabled.read().strip() == "enabled"
    return lit


def wait_until_lit(expected: int) -> bool:
    deadline = time.monotonic() + LIGHT_TIMEOUT_SEC
    while lit_connectors() < expected:
        if time.monotonic() >= deadline:
            return False
        time.sleep(LIGHT_POLL_SEC)
    return True


def reapply_current_config(display: Gio.DBusProxy, state) -> None:
    serial, monitors, logical_monitors, properties = state
    monitor_configs = {}
    for (connector, *_), modes, props in monitors:
        mode_id = next(mode[0] for mode in modes if mode[-1].get("is-current"))
        options = {
            key: GLib.Variant("u", props[key]) for key in MONITOR_OPTION_KEYS if key in props
        }
        monitor_configs[connector] = (connector, mode_id, options)

    logical_configs = [
        (x, y, scale, transform, primary, [monitor_configs[m[0]] for m in members])
        for x, y, scale, transform, primary, members, _props in logical_monitors
    ]
    apply_properties = {}
    if properties.get("supports-changing-layout-mode") and "layout-mode" in properties:
        apply_properties["layout-mode"] = GLib.Variant("u", properties["layout-mode"])

    display.call_sync(
        "ApplyMonitorsConfig",
        GLib.Variant(
            "(uua(iiduba(ssa{sv}))a{sv})",
            (serial, CONFIG_METHOD_TEMPORARY, logical_configs, apply_properties),
        ),
        Gio.DBusCallFlags.NONE,
        -1,
        None,
    )


def turn_on() -> int:
    display = display_config()
    try:
        set_mode(display, ON_MODE)
    except GLib.Error as error:
        log(f"Error: failed to turn the display on: {error.message}")
        return 1

    # Only monitors in use count, so a closed lid or disabled output is fine.
    try:
        state = display.call_sync(
            "GetCurrentState", None, Gio.DBusCallFlags.NONE, -1, None
        ).unpack()
        expected = sum(len(logical[5]) for logical in state[2])
        if wait_until_lit(expected):
            return 0
        log(f"only {lit_connectors()} of {expected} outputs lit; re-applying the monitor configuration")
        reapply_current_config(display, state)
    except (GLib.Error, StopIteration, KeyError) as error:
        log(f"Warning: could not re-light the display: {error}")
        return 0

    if wait_until_lit(expected):
        log("display re-lit after re-applying the monitor configuration")
    else:
        log(f"Warning: still only {lit_connectors()} of {expected} outputs lit")
    return 0


def main() -> int:
    command = sys.argv[1] if len(sys.argv) == 2 else ""
    if command == "hold":
        return hold()
    if command == "on":
        return turn_on()
    print("Usage: dpms-display.py hold|on", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
