return {
    "mrcjkb/rustaceanvim",
    opts = {
        server = {
            default_settings = {
                ["rust-analyzer"] = {
                    -- Use clippy for linting (catches more issues than cargo check)
                    check = {
                        command = "clippy",
                        extraArgs = { "--no-deps" },
                    },
                    -- Enable all features for better completions
                    cargo = {
                        allFeatures = true,
                        loadOutDirsFromCheck = true,
                    },
                    -- Proc macro support
                    procMacro = {
                        enable = true,
                    },
                    -- Inlay hints configuration
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
    },
}
