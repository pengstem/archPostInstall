return {
  "nvim-neo-tree/neo-tree.nvim",
  version = "*", -- 可选：锁定稳定版本
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  -- 以下 opts 会被 LazyVim 自动传入 require("neo-tree").setup()
  opts = {
    filesystem = {
      follow_current_file = true,
      filtered_items = {
        visible = true, -- “暗置”隐藏项而非彻底移除
        hide_dotfiles = false, -- 显示以 . 开头的文件
        hide_gitignored = false, -- 显示 .gitignore 中列出的文件并标记
        -- 可选：按名称永不/总是隐藏
        -- never_show = { ".DS_Store", "thumbs.db" },
      },
    },
    git_status = {
      enabled = true, -- 打开 Git 状态组件
    },
    window = {
      position = "left",
      width = 30,
    },
  },
}
