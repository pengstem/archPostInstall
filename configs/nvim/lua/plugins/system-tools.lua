local mason_bin = vim.fs.normalize(vim.fn.stdpath("data") .. "/mason/bin")

local function is_mason_path(path)
  path = vim.fs.normalize(path)
  return path == mason_bin or vim.startswith(path, mason_bin .. "/")
end

local function system_executable(command)
  local path = vim.fn.exepath(command)
  if path ~= "" and not is_mason_path(path) then
    return vim.fs.normalize(path)
  end

  -- Mason may already be on PATH when this function runs. Search the other
  -- PATH entries as well, so an existing system binary cannot be hidden by it.
  local separator = package.config:sub(1, 1) == "\\" and ";" or ":"
  for _, directory in ipairs(vim.split(vim.env.PATH or "", separator, { plain = true })) do
    if directory ~= "" and not is_mason_path(directory) then
      local candidate = vim.fs.joinpath(directory, command)
      if vim.fn.executable(candidate) == 1 then
        return vim.fs.normalize(candidate)
      end
    end
  end

  return nil
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
  ts_ls = "typescript-language-server",
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
        return system_executable(command) == nil
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

      opts.setup = opts.setup or {}
      for server, command in pairs(lsp_commands) do
        local path = system_executable(command)
        if path then
          local server_opts = opts.servers[server] or {}
          server_opts.mason = false

          -- Keep custom arguments supplied by LazyVim, but make an explicit
          -- command unambiguous when the server config already provides one.
          if type(server_opts.cmd) == "table" and #server_opts.cmd > 0 then
            server_opts.cmd = vim.deepcopy(server_opts.cmd)
            server_opts.cmd[1] = path
          end
          opts.servers[server] = server_opts

          -- LazyVim otherwise lets mason-lspconfig automatically enable any
          -- old Mason installation of this server. Configure and enable the
          -- system server here, then exclude it from Mason's auto-enable path.
          local setup = opts.setup[server]
          opts.setup[server] = function(server_name, server_config)
            if setup then
              setup(server_name, server_config)
            end
            vim.lsp.config(server_name, server_config)
            vim.lsp.enable(server_name)
            return true
          end
        end
      end
    end,
  },
  {
    "mrcjkb/rustaceanvim",
    optional = true,
    opts = function(_, opts)
      local path = system_executable("rust-analyzer")
      if path then
        opts.server = opts.server or {}
        opts.server.cmd = { path }
      end
    end,
  },
}
