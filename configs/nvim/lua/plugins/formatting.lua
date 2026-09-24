return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}

      opts.formatters_by_ft.c = { "clang-format" }
      opts.formatters_by_ft.cpp = { "clang-format" }

      for _, filetype in ipairs({
        "javascript",
        "javascriptreact",
        "typescript",
        "typescriptreact",
        "vue",
        "json",
        "jsonc",
        "css",
        "scss",
        "html",
      }) do
        opts.formatters_by_ft[filetype] = { "prettier" }
      end
    end,
  },
}
