-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.clipboard = {
  name = "wl-clipboard-timeout",
  copy = {
    ["+"] = { "wl-copy", "--type", "text/plain" },
    ["*"] = { "wl-copy", "--primary", "--type", "text/plain" },
  },
  paste = {
    ["+"] = { "timeout", "1s", "wl-paste", "--no-newline" },
    ["*"] = { "timeout", "1s", "wl-paste", "--no-newline", "--primary" },
  },
  cache_enabled = 1,
}

vim.opt.clipboard = "unnamedplus"
