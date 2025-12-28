-- ~/.config/nvim/lua/plugins/blink.lua
return {
  "saghen/blink.cmp",
  -- 若你想跟随主分支而不是最新 tag，可改成：version = false
  -- build = "cargo build --release",
  opts = function(_, opts)
    ------------------------------------------------------------
    -- 1) 何时启用/禁用
    ------------------------------------------------------------
    -- opts.enabled = function()
    --   -- 在 markdown / gitcommit / prompt buffer 里关闭
    --   return not vim.tbl_contains({ "markdown", "gitcommit" }, vim.bo.filetype) and vim.bo.buftype ~= "prompt"
    -- end
    --
    -- -- 彻底关闭 cmdline 补全（:、/ 等命令行模式）
    -- opts.cmdline = { enabled = false }
    --
    -- ------------------------------------------------------------
    -- -- 2) 完成菜单行为
    -- ------------------------------------------------------------
    -- opts.completion = vim.tbl_deep_extend("force", opts.completion or {}, {
    --   -- 别自动弹；按 <C-Space> 手动触发
    --   menu = { auto_show = false, border = "single" },
    --   -- 文档窗口延迟 300 ms 弹出，避免闪烁
    --   documentation = { auto_show = true, auto_show_delay_ms = 300 },
    --   -- 关闭自动括号
    --   accept = { auto_brackets = { enabled = false } },
    --   -- 不预选第 1 项，避免误触 <CR>
    --   list = { selection = { preselect = false } },
    --   -- 开启 ghost-text 预览
    --   ghost_text = { enabled = true },
    -- })

    ------------------------------------------------------------
    -- 3) 快捷键
    ------------------------------------------------------------
    opts.keymap = {
      -- “super-tab” 预设：Tab=确认/跳占位符，⇧Tab=后退
      preset = "enter",
      -- ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
      -- ["<C-e>"] = { "hide", "fallback" }, -- 关闭菜单
      -- -- ↑↓ 选项，与 Neovim 内置移动保持一致
      ["<Up>"] = { "select_prev", "fallback" },
      ["<Down>"] = { "select_next", "fallback" },
      ["<Tab>"] = { "select_next", "fallback" },
      ["<S-Tab>"] = { "select_prev", "fallback" },
      -- 自己加一个“一键接受 + 换行”
      -- ["<C-l>"] = { "accept_and_enter" },
    }

    ------------------------------------------------------------
    -- 4) 补全来源
    ------------------------------------------------------------
    -- opts.sources = {
    --   -- 常驻：LSP / 文件路径 / Snippet
    --   default = { "lsp", "path", "snippets" },
    --   -- 兼容 nvim-cmp 源示例（可按需添加）
    --   compat = { "nvim_lsp_signature_help" },
    --   providers = {
    --     -- 示例：把 lazydev 集成进来并优先显示
    --     lazydev = {
    --       name = "LazyDev",
    --       module = "lazydev.integrations.blink",
    --       score_offset = 100,
    --     },
    --   },
    -- }

    -- Snippet 引擎：用 luasnip 而不是 vim.snippet
    -- opts.snippets = { preset = "luasnip" }

    -- 开启 Experimental 签名帮助
    opts.signature = { enabled = true }
  end,
}
