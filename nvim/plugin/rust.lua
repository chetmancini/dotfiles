vim.g.rustaceanvim = {
  server = {
    default_settings = {
      ["rust-analyzer"] = {
        check = {
          command = "clippy",
          extraArgs = { "--no-deps" },
        },
        cargo = {
          allFeatures = true,
          loadOutDirsFromCheck = true,
        },
        procMacro = {
          enable = true,
        },
        inlayHints = {
          bindingModeHints = { enable = true },
          closingBraceHints = { minLines = 20 },
          closureReturnTypeHints = { enable = "with_block" },
          lifetimeElisionHints = { enable = "skip_trivial" },
          parameterHints = { enable = true },
          typeHints = { enable = true },
        },
      },
    },
  },
}

require("crates").setup()
