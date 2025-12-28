return {
  "keaising/im-select.nvim",
  event = "VeryLazy",
  opts = {
    -- Normal mode 强制用英文键盘
    default_im_select = "keyboard-us", -- 你的英文布局名
    default_command = "fcitx5-remote", -- 或 ibus / im-select.exe …
    -- 退出插入、命令行、失焦时切英文
    set_default_events = { "InsertLeave", "CmdlineLeave", "FocusLost" },
    -- 重新进插入/命令行时恢复离开前用的输入法
    set_previous_events = { "InsertEnter", "CmdlineEnter" },
    async_switch_im = true, -- 不阻塞界面
  },
}
