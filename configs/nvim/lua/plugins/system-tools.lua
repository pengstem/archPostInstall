local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"

local function is_system_executable(command)
  local path = vim.fn.exepath(command)
  return path ~= "" and not vim.startswith(vim.fs.normalize(path), vim.fs.normalize(mason_bin))
end

local lsp_commands = {
  bashls = "bash-language-server",
  clangd = "clangd",
  docker_compose_language_service = "docker-compose-langserver",
  dockerls = "docker-langserver",
  jsonls = "vscode-json-language-server",
  lua_ls = "lua-language-server",
  marksman = "marksman",
  ocamllsp = "ocamllsp",
  ruff = "ruff",
  taplo = "taplo",
  ty = "ty",
  vtsls = "vtsls",
  yamlls = "yaml-language-server",
}

local mason_tool_commands = {
  codelldb = "codelldb",
  hadolint = "hadolint",
  ["markdown-toc"] = "markdown-toc",
  ["markdownlint-cli2"] = "markdownlint-cli2",
  ruff = "ruff",
  shellcheck = "shellcheck",
  shfmt = "shfmt",
  stylua = "stylua",
  ty = "ty",
  uv = "uv",
}

return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      opts.PATH = "append"
      opts.ensure_installed = vim.tbl_filter(function(tool)
        local command = mason_tool_commands[tool] or tool
        return not is_system_executable(command)
      end, opts.ensure_installed)
      return opts
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.pyright = { enabled = false }

      opts.servers.ruff = vim.tbl_deep_extend("force", opts.servers.ruff or {}, {
        cmd = { "ruff", "server" },
      })
      opts.servers.ty = vim.tbl_deep_extend("force", opts.servers.ty or {}, {
        cmd = { "ty", "server" },
      })

      for server, command in pairs(lsp_commands) do
        if is_system_executable(command) then
          opts.servers[server] = vim.tbl_deep_extend("force", opts.servers[server] or {}, {
            mason = false,
          })
        end
      end
    end,
  },
  {
    "mrcjkb/rustaceanvim",
    optional = true,
    opts = function(_, opts)
      if is_system_executable("rust-analyzer") then
        opts.server = opts.server or {}
        opts.server.cmd = { "rust-analyzer" }
      end
    end,
  },
}
