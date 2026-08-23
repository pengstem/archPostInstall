#!/usr/bin/python3

"""GNOME idle-monitor and custom-shortcut integration for the screensaver."""

from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys
from collections.abc import Sequence

import gi

gi.require_version("Gio", "2.0")
gi.require_version("GLibUnix", "2.0")
from gi.repository import Gio, GLib, GLibUnix

BUS_NAME = "org.gnome.Mutter.IdleMonitor"
OBJECT_PATH = "/org/gnome/Mutter/IdleMonitor/Core"
INTERFACE = "org.gnome.Mutter.IdleMonitor"
MEDIA_KEYS_SCHEMA = "org.gnome.settings-daemon.plugins.media-keys"
CUSTOM_SCHEMA = "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
SHORTCUT_NAME = "Omarchy 风格屏保"


def idle_proxy() -> Gio.DBusProxy:
    return Gio.DBusProxy.new_for_bus_sync(
        Gio.BusType.SESSION,
        Gio.DBusProxyFlags.NONE,
        None,
        BUS_NAME,
        OBJECT_PATH,
        INTERFACE,
        None,
    )


def add_idle_watch(proxy: Gio.DBusProxy, timeout_seconds: int) -> int:
    params = GLib.Variant("(t)", (timeout_seconds * 1000,))
    result = proxy.call_sync(
        "AddIdleWatch", params, Gio.DBusCallFlags.NONE, -1, None
    )
    return int(result.unpack()[0])


def add_active_watch(proxy: Gio.DBusProxy) -> int:
    result = proxy.call_sync(
        "AddUserActiveWatch", None, Gio.DBusCallFlags.NONE, -1, None
    )
    return int(result.unpack()[0])


def get_idle_time(proxy: Gio.DBusProxy) -> int:
    result = proxy.call_sync(
        "GetIdletime", None, Gio.DBusCallFlags.NONE, -1, None
    )
    return int(result.unpack()[0])


def remove_watch(proxy: Gio.DBusProxy, watch_id: int) -> None:
    if watch_id == 0:
        return
    try:
        proxy.call_sync(
            "RemoveWatch",
            GLib.Variant("(u)", (watch_id,)),
            Gio.DBusCallFlags.NONE,
            -1,
            None,
        )
    except GLib.Error:
        pass


class IdleDaemon:
    def __init__(self, timeout: int, launcher: str) -> None:
        self.timeout = timeout
        self.launcher = launcher
        self.proxy = idle_proxy()
        self.loop = GLib.MainLoop()
        self.idle_watch = 0
        self.active_watch = 0
        self.proxy.connect("g-signal", self._on_signal)

    def _action(self, action: str) -> None:
        result = subprocess.run([self.launcher, action], check=False)
        if result.returncode != 0:
            print(
                f"screensaver {action} failed with status {result.returncode}",
                file=sys.stderr,
                flush=True,
            )

    def _arm_idle(self) -> None:
        self.idle_watch = add_idle_watch(self.proxy, self.timeout)

    def _arm_active(self) -> None:
        self.active_watch = add_active_watch(self.proxy)

    def _on_signal(
        self,
        _proxy: Gio.DBusProxy,
        _sender_name: str,
        signal_name: str,
        parameters: GLib.Variant,
    ) -> None:
        if signal_name != "WatchFired":
            return
        watch_id = int(parameters.unpack()[0])

        if watch_id == self.idle_watch:
            remove_watch(self.proxy, self.idle_watch)
            self.idle_watch = 0
            self._action("start")
            self._arm_active()
        elif watch_id == self.active_watch:
            self.active_watch = 0
            self._action("stop")
            self._arm_idle()

    def stop(self) -> bool:
        remove_watch(self.proxy, self.idle_watch)
        remove_watch(self.proxy, self.active_watch)
        self._action("stop")
        self.loop.quit()
        return GLib.SOURCE_REMOVE

    def run(self) -> None:
        if get_idle_time(self.proxy) >= self.timeout * 1000:
            self._arm_active()
        else:
            self._arm_idle()
        GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, self.stop)
        GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, self.stop)
        self.loop.run()


def wait_for_activity(pid: int) -> None:
    proxy = idle_proxy()
    loop = GLib.MainLoop()
    watch_id = add_active_watch(proxy)

    def on_signal(
        _proxy: Gio.DBusProxy,
        _sender_name: str,
        signal_name: str,
        parameters: GLib.Variant,
    ) -> None:
        if signal_name != "WatchFired" or int(parameters.unpack()[0]) != watch_id:
            return
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        loop.quit()

    def stop() -> bool:
        remove_watch(proxy, watch_id)
        loop.quit()
        return GLib.SOURCE_REMOVE

    proxy.connect("g-signal", on_signal)
    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, stop)
    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, stop)
    loop.run()


def shortcut_settings(path: str) -> Gio.Settings:
    return Gio.Settings.new_with_path(CUSTOM_SCHEMA, path)


def install_shortcut(binding: str, command: str) -> None:
    media_keys = Gio.Settings.new(MEDIA_KEYS_SCHEMA)
    paths = list(media_keys.get_strv("custom-keybindings"))
    selected_path = ""

    for path in paths:
        settings = shortcut_settings(path)
        existing_name = settings.get_string("name")
        existing_command = settings.get_string("command")
        existing_binding = settings.get_string("binding")
        if existing_name == SHORTCUT_NAME or existing_command == command:
            selected_path = path
            break
        if existing_binding == binding:
            raise RuntimeError(
                f"shortcut {binding} is already used by {existing_name or existing_command}"
            )

    if not selected_path:
        used = set(paths)
        index = 0
        while True:
            candidate = (
                "/org/gnome/settings-daemon/plugins/media-keys/"
                f"custom-keybindings/custom{index}/"
            )
            if candidate not in used:
                selected_path = candidate
                break
            index += 1
        paths.append(selected_path)
        media_keys.set_strv("custom-keybindings", paths)

    settings = shortcut_settings(selected_path)
    settings.set_string("name", SHORTCUT_NAME)
    settings.set_string("command", command)
    settings.set_string("binding", binding)
    Gio.Settings.sync()
    print(f"GNOME shortcut: {binding} -> {command}")


def remove_shortcut(command: str) -> None:
    media_keys = Gio.Settings.new(MEDIA_KEYS_SCHEMA)
    paths = list(media_keys.get_strv("custom-keybindings"))
    retained: list[str] = []

    for path in paths:
        settings = shortcut_settings(path)
        if (
            settings.get_string("name") == SHORTCUT_NAME
            or settings.get_string("command") == command
        ):
            settings.reset("name")
            settings.reset("command")
            settings.reset("binding")
        else:
            retained.append(path)

    if retained != paths:
        media_keys.set_strv("custom-keybindings", retained)
        Gio.Settings.sync()
        print("GNOME screensaver shortcut removed")


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="action", required=True)

    daemon = subparsers.add_parser("daemon")
    daemon.add_argument("--timeout", required=True, type=positive_int)
    daemon.add_argument("--launcher", required=True)

    wait_active = subparsers.add_parser("wait-active")
    wait_active.add_argument("--pid", required=True, type=positive_int)

    install = subparsers.add_parser("install-shortcut")
    install.add_argument("--binding", required=True)
    install.add_argument("--command", dest="shortcut_command", required=True)

    remove = subparsers.add_parser("remove-shortcut")
    remove.add_argument("--command", dest="shortcut_command", required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    try:
        if args.action == "daemon":
            IdleDaemon(args.timeout, args.launcher).run()
        elif args.action == "wait-active":
            wait_for_activity(args.pid)
        elif args.action == "install-shortcut":
            install_shortcut(args.binding, args.shortcut_command)
        elif args.action == "remove-shortcut":
            remove_shortcut(args.shortcut_command)
    except (GLib.Error, RuntimeError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
