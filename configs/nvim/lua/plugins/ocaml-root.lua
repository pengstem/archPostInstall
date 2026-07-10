return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ocamllsp = {
          root_markers = {
            { "dune-project", "dune-workspace" },
            { "*.opam", "opam", "esy.json", "package.json" },
            { ".git" },
          },
        },
      },
    },
  },
}
