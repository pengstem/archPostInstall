-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Warn when editing a file that likely needs root to save
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  callback = function(args)
    local file = vim.api.nvim_buf_get_name(args.buf)
    if file == "" then
      return
    end
    -- Skip non-file buffers
    if vim.bo[args.buf].buftype ~= "" then
      return
    end

    local euid = vim.fn.getenv("EUID")
    if euid == "" then
      -- fallback: assume non-root
      euid = "1000"
    end

    -- If not root and file isn't writable, warn
    local writable = vim.fn.filewritable(file) == 1
    if not writable and vim.fn.filereadable(file) == 0 then
      -- New file: check if parent directory is writable
      local dir = vim.fn.fnamemodify(file, ":h")
      writable = vim.fn.filewritable(dir) == 2
    end

    if euid ~= "0" and not writable then
      vim.schedule(function()
        vim.notify(
          ("Likely no write permission: %s\nTip: reopen with sudo or use Suda.vim to write."):format(file),
          vim.log.levels.WARN,
          { title = "Permission warning" }
        )
      end)
    end
  end,
})
