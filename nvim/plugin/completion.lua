require("blink.cmp").setup({
  fuzzy = {
    -- vim.pack installs blink.cmp without guaranteeing the Rust fuzzy binary is
    -- built into the package path. For a portable startup, use the Lua matcher.
    implementation = "lua",
  },
  keymap = { preset = "default" },
  appearance = {
    nerd_font_variant = "mono",
  },
  sources = {
    default = { "lsp", "path", "snippets", "buffer", "copilot" },
    providers = {
      copilot = {
        name = "copilot",
        module = "blink-copilot",
        score_offset = 100,
        async = true,
      },
    },
  },
  completion = {
    accept = { auto_brackets = { enabled = true } },
    menu = { draw = { treesitter = { "lsp" } } },
    documentation = { auto_show = true, auto_show_delay_ms = 200 },
  },
  signature = { enabled = true },
})
