# Neovim

> LazyVim-based editor with 40+ plugins for modern development

## Overview

Neovim configuration built on [LazyVim](https://www.lazyvim.org/) with custom plugins for Rust, Python, TypeScript, and AI-assisted coding via GitHub Copilot. Integrates seamlessly with tmux for navigation.

## Setup

**Config directory:** `nvim/` symlinked to `~/.config/nvim`

**Dependencies:**
- `neovim` (via Brewfile)
- Language servers installed via Mason

## Directory Structure

```
nvim/
├── init.lua                    # Entry point (loads config.lazy)
├── lazy-lock.json              # Plugin version lock file
├── lua/
│   ├── config/
│   │   ├── lazy.lua            # Plugin manager setup
│   │   ├── keymaps.lua         # Custom keymaps (uses LazyVim defaults)
│   │   └── options.lua         # Editor options
│   └── plugins/
│       ├── colorscheme.lua     # Catppuccin theme
│       ├── copilot.lua         # GitHub Copilot
│       ├── rust.lua            # Rust analyzer config
│       └── tmux-navigator.lua  # Tmux integration
```

## Quick Reference

### Leader Keys

| Key | Purpose |
|-----|---------|
| `Space` | Leader key |
| `\` | Local leader (filetype-specific) |

### Navigation

| Action | Keybinding | Notes |
|--------|------------|-------|
| Navigate left | `Ctrl-h` | Works across tmux panes |
| Navigate down | `Ctrl-j` | Works across tmux panes |
| Navigate up | `Ctrl-k` | Works across tmux panes |
| Navigate right | `Ctrl-l` | Works across tmux panes |
| Previous pane/split | `Ctrl-\` | Toggle back |

### Copilot

| Action | Keybinding | Notes |
|--------|------------|-------|
| Accept suggestion | `Tab` | Full suggestion |
| Accept word | `Ctrl-Right` | Next word only |
| Accept line | `Ctrl-l` | Current line |
| Next suggestion | `Alt-]` | Cycle forward |
| Previous suggestion | `Alt-[` | Cycle backward |
| Dismiss | `Ctrl-]` | Clear suggestion |

### LazyVim Defaults

This config uses LazyVim defaults. Common keybindings:

| Action | Keybinding |
|--------|------------|
| File explorer | `Space + e` |
| Find files | `Space + Space` |
| Live grep | `Space + /` |
| Buffers | `Space + ,` |
| Recent files | `Space + fr` |
| Save file | `Space + w` or `Ctrl-s` |
| Quit | `Space + qq` |
| LSP actions | `Space + ca` |
| Format | `Space + cf` |

See [LazyVim keymaps](https://www.lazyvim.org/keymaps) for the complete list.

## Features

### Theme: Catppuccin

Catppuccin colorscheme with transparent background enabled, allowing Ghostty's transparency to show through.

```lua
-- nvim/lua/plugins/colorscheme.lua
opts = {
    transparent_background = true,
}
```

### Language Support

Enabled via LazyVim extras in `lua/config/lazy.lua`:

| Language | Extra | Features |
|----------|-------|----------|
| Rust | `lang.rust` | LSP, rustfmt, clippy |
| Python | `lang.python` | pyright, ruff |
| TypeScript | `lang.typescript` | tsserver, prettier |
| Tailwind | `lang.tailwind` | CSS completions |

### Rust Configuration

Custom `rustaceanvim` config with enhanced settings:

```lua
-- nvim/lua/plugins/rust.lua
["rust-analyzer"] = {
    check = {
        command = "clippy",  -- Use clippy instead of cargo check
    },
    cargo = {
        allFeatures = true,  -- Enable all features for completions
    },
    procMacro = {
        enable = true,       -- Proc macro support
    },
    inlayHints = {
        bindingModeHints = { enable = true },
        closingBraceHints = { minLines = 20 },
        closureReturnTypeHints = { enable = "with_block" },
        lifetimeElisionHints = { enable = "skip_trivial" },
        parameterHints = { enable = true },
        typeHints = { enable = true },
    },
}
```

### GitHub Copilot

Auto-trigger enabled with custom keybindings. Works in:
- All code files (auto)
- Markdown files
- YAML files
- Git commit messages

### Tmux Integration

`vim-tmux-navigator` provides seamless navigation. The same `Ctrl-h/j/k/l` keys work for:
- Neovim splits
- Tmux panes

No mental context switch needed.

## Plugin List

40+ plugins managed by lazy.nvim. Key plugins:

**UI & Theme:**
- `catppuccin` - Colorscheme
- `bufferline.nvim` - Tab/buffer line
- `lualine.nvim` - Status line
- `neo-tree.nvim` - File explorer
- `noice.nvim` - UI enhancements
- `which-key.nvim` - Keybinding hints

**Editor:**
- `flash.nvim` - Enhanced motions
- `gitsigns.nvim` - Git decorations
- `todo-comments.nvim` - TODO highlighting
- `trouble.nvim` - Diagnostics list
- `mini.pairs` - Auto-pairing

**LSP & Completion:**
- `nvim-lspconfig` - LSP configuration
- `mason.nvim` - LSP/formatter installer
- `blink.cmp` - Completion engine
- `conform.nvim` - Formatting
- `nvim-lint` - Linting

**Language:**
- `rustaceanvim` - Rust tools
- `nvim-treesitter` - Syntax highlighting
- `nvim-ts-autotag` - HTML/JSX auto-close

**AI:**
- `copilot.lua` - GitHub Copilot
- `blink-copilot` - Copilot + completion

**Navigation:**
- `vim-tmux-navigator` - Tmux integration
- `fzf-lua` - Fuzzy finder

## Customization

### Add a Plugin

Create a new file in `nvim/lua/plugins/`:

```lua
-- nvim/lua/plugins/example.lua
return {
    "author/plugin-name",
    opts = {
        -- configuration
    },
}
```

### Override LazyVim Defaults

```lua
-- nvim/lua/plugins/override.lua
return {
    "LazyVim/LazyVim",
    opts = {
        colorscheme = "tokyonight",
    },
}
```

### Add Custom Keymaps

Edit `nvim/lua/config/keymaps.lua`:

```lua
vim.keymap.set("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })
```

### Change Theme

Edit `nvim/lua/plugins/colorscheme.lua`:

```lua
return {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        vim.cmd.colorscheme("tokyonight")
    end,
}
```

## Key Settings

From `nvim/lua/config/options.lua`:

| Setting | Value | Purpose |
|---------|-------|---------|
| `wrap` | `false` | No line wrapping |

Most settings use LazyVim defaults.

## Troubleshooting

### LSP not working

1. Open neovim and run `:Mason`
2. Install the language server (e.g., `rust-analyzer`, `pyright`)
3. Restart neovim

### Copilot not suggesting

1. Run `:Copilot auth` to authenticate
2. Check `:Copilot status`
3. Ensure the filetype is supported

### Plugins not loading

1. Run `:Lazy` to open plugin manager
2. Press `S` to sync plugins
3. Check for errors in `:messages`

### Tmux navigation not working

Ensure both are configured:
- Neovim: `vim-tmux-navigator` plugin loaded
- tmux: Smart pane switching in `.tmux.conf`
