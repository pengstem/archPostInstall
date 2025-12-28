return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      dashboard = {
        enabled = true,
        preset = {
          header = [[
  ███╗   ██╗ █████╗ ███████╗████████╗███████╗███╗   ███╗  
  ████╗  ██║██╔══██╗██╔════╝╚══██╔══╝██╔════╝████╗ ████║  
  ██╔██╗ ██║███████║███████╗   ██║   █████╗  ██╔████╔██║  
  ██║╚██╗██║██╔══██║╚════██║   ██║   ██╔══╝  ██║╚██╔╝██║  
  ██║ ╚████║██║  ██║███████║   ██║   ███████╗██║ ╚═╝ ██║  
  ╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝  
]],
        },
        -- 确保 header 格式居中对齐
        formats = {
          header = { "%s", align = "center" },
        },
        sections = {
          -- Header 部分 - 已确保居中
          { section = "header" },

          -- 左边：Keymaps（快捷键）面板
          {
            pane = 1,
            icon = " ",
            title = "Keymaps",
            section = "keys",
            indent = 2,
            padding = 1,
            gap = 1,
          },

          -- 右边：Recent Files（最近文件）面板
          {
            pane = 2,
            icon = " ",
            title = "Recent Files",
            section = "recent_files",
            indent = 2,
            padding = 1,
            gap = 1,
          },

          -- 右边：Projects（项目）面板
          {
            pane = 2,
            icon = " ",
            title = "Projects",
            section = "projects",
            indent = 2,
            padding = 1,
            gap = 1,
          },

          { section = "startup" },
        },
      },
    },
  },
}
