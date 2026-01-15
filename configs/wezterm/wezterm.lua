local wezterm = require("wezterm")

local config = wezterm.config_builder()
local act = wezterm.action

config.enable_wayland = false
config.window_background_opacity = 0.85
config.enable_tab_bar = false
config.window_decorations = "NONE"
config.window_padding = {
    left = 10,
    right = 10,
    top = 10,
    bottom = 10,
}

config.scrollback_lines = 10000
config.adjust_window_size_when_changing_font_size = false
config.audible_bell = "Disabled"
config.inactive_pane_hsb = {
    saturation = 0.9,
    brightness = 0.6,
}

config.font = wezterm.font_with_fallback({
    "Maple Mono NF CN",
    "JetBrains Mono",
    "Noto Sans Mono CJK SC",
    "Noto Sans Mono",
    "Noto Color Emoji",
})
config.font_size = 13.0
config.line_height = 1.08

config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }

config.keys = {
    { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
    { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },

    { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
    { key = "w", mods = "LEADER", action = act.CloseCurrentTab({ confirm = true }) },
    { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },

    { key = "v", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "s", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },

    { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
    { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
    { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
    { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },

    { key = "H", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Left", 5 }) },
    { key = "J", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Down", 5 }) },
    { key = "K", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Up", 5 }) },
    { key = "L", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Right", 5 }) },

    { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
    { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
    { key = "t", mods = "LEADER", action = act.ShowTabNavigator },

    { key = "f", mods = "LEADER", action = act.Search({ CaseInSensitiveString = "" }) },
    { key = "o", mods = "LEADER", action = act.QuickSelect },
    { key = "r", mods = "LEADER", action = act.ReloadConfiguration },

    { key = "LeftArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Left") },
    { key = "DownArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Down") },
    { key = "UpArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Up") },
    { key = "RightArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Right") },

    { key = "=", mods = "CTRL", action = act.IncreaseFontSize },
    { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
    { key = "0", mods = "CTRL", action = act.ResetFontSize },
}

return config
