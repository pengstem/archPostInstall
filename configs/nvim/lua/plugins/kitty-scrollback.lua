return {
  {
    "mikesmithgh/kitty-scrollback.nvim",
    cmd = {
      "KittyScrollbackGenerateKittens",
      "KittyScrollbackCheckHealth",
      "KittyScrollbackGenerateCommandLineEditing",
    },
    event = { "User KittyScrollbackLaunch" },
    opts = {
      {
        scrollback_tempfile = false,
        status_window = {
          autoclose = true,
        },
      },
    },
  },
}
