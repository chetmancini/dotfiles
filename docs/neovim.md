# Neovim

> Modular Neovim config using built-in `vim.pack` plugin management

## Overview

Neovim configuration managed with **`vim.pack`** (Neovim’s built-in package
manager), not LazyVim or lazy.nvim. Plugins are declared in `nvim/init.lua`;
feature setup lives under `nvim/plugin/*.lua`. Includes Catppuccin, LSP via
Mason, blink.cmp completion, Copilot, fzf-lua, neo-tree, and language extras
for Rust, Python, and SQL. Tmux navigation works with `Ctrl-h/j/k/l`.

## Setup

**Config directory:** `nvim/` symlinked to `~/.config/nvim`

**Dependencies:**
- `neovim` (via core Brewfile)
- Language servers / tools via `:Mason` as needed

## Directory Structure

```
nvim/
├── init.lua                 # Leaders, options, vim.pack.add, colorscheme, keymaps
├── nvim-pack-lock.json      # Plugin lock file for vim.pack
├── stylua.toml              # Lua formatter config
└── plugin/                  # Auto-loaded feature modules
    ├── completion.lua       # blink.cmp + snippets
    ├── copilot.lua          # GitHub Copilot
    ├── editor.lua           # mini.*, flash, grug-far, persistence
    ├── finder.lua           # fzf-lua + neo-tree
    ├── format.lua           # conform.nvim + nvim-lint
    ├── git.lua              # gitsigns
    ├── lsp.lua              # lspconfig, mason, diagnostics
    ├── python.lua           # venv-selector
    ├── rust.lua             # rustaceanvim + crates.nvim
    ├── sql.lua              # vim-dadbod stack
    ├── tmux.lua             # vim-tmux-navigator keymaps
    ├── treesitter.lua       # treesitter + textobjects
    └── ui.lua               # bufferline, lualine, noice, which-key, trouble
```

There is **no** `lua/config/` or `lua/plugins/` LazyVim layout.

## Quick Reference

### Leader Keys

| Key | Purpose |
|-----|---------|
| `Space` | Leader |
| `\` | Local leader |

### Navigation (tmux-aware)

| Action | Keybinding |
|--------|------------|
| Left / down / up / right | `Ctrl-h` / `j` / `k` / `l` |
| Previous pane | `Ctrl-\` |

### Find / files

| Action | Keybinding |
|--------|------------|
| Explorer (neo-tree) | `Space e` |
| Find files | `Space Space` or `Space ff` |
| Live grep | `Space /` or `Space fg` |
| Buffers | `Space ,` or `Space fb` |
| Recent files | `Space fr` |

### Editor / windows

| Action | Keybinding |
|--------|------------|
| Save | `Ctrl-s` |
| Quit all | `Space qq` |
| Delete buffer | `Space bd` |
| Split below / right | `Space -` / `Space \|` |
| Format | `Space cf` |
| Line diagnostics | `Space cd` |
| Code action / rename | `Space ca` / `Space cr` |

### Diagnostics / todos

| Action | Keybinding |
|--------|------------|
| Trouble diagnostics | `Space xx` |
| Buffer diagnostics | `Space xX` |
| Todo search | `Space st` |

### Copilot

Configured in `plugin/copilot.lua` (accept/dismiss bindings live there). Auth
with `:Copilot auth` if suggestions do not appear.

## Features

### Theme: Catppuccin

Applied in `init.lua` with `transparent_background = true` so Ghostty
transparency shows through.

### Plugin management: vim.pack

Plugins are added with `vim.pack.add({ ... })` in `init.lua`. On treesitter
updates, a `PackChanged` autocmd runs `TSUpdate`.

To add a plugin:

1. Append the GitHub URL (or table with `src` / `name`) to `vim.pack.add` in `init.lua`.
2. Put setup code in a new or existing file under `nvim/plugin/`.
3. Restart Neovim (or reload as appropriate for your workflow).

### Language support

| Area | Plugins / notes |
|------|-----------------|
| Rust | rustaceanvim, crates.nvim (`plugin/rust.lua`) |
| Python | venv-selector (`plugin/python.lua`); LSP via Mason (e.g. pyright, ruff) |
| SQL | vim-dadbod, dadbod-ui, dadbod-completion |
| General LSP | nvim-lspconfig, mason.nvim, mason-lspconfig |
| Completion | blink.cmp, friendly-snippets, blink-copilot |
| Format / lint | conform.nvim, nvim-lint |

### GitHub Copilot

`copilot.lua` + blink-copilot integration for inline and completion-menu
suggestions.

### Tmux integration

`christoomey/vim-tmux-navigator` with maps in `plugin/tmux.lua`. Same
`Ctrl-h/j/k/l` move across Neovim splits and tmux panes when both are
configured.

## Plugin inventory (from `init.lua`)

**UI & theme:** catppuccin, bufferline, lualine, noice, nui, which-key, neo-tree  
**Editor:** mini.ai/pairs/surround/icons, flash, grug-far, persistence  
**LSP & tools:** nvim-lspconfig, mason, mason-lspconfig, lazydev, conform, nvim-lint  
**Completion / AI:** blink.cmp, friendly-snippets, blink-copilot, copilot.lua  
**Nav / git:** fzf-lua, gitsigns, plenary  
**Diagnostics:** trouble, todo-comments  
**Lang:** rustaceanvim, crates.nvim, vim-dadbod*, venv-selector  
**Tmux:** vim-tmux-navigator  
**Treesitter:** nvim-treesitter, textobjects, nvim-ts-autotag, ts-comments  

## Key settings

Set in `init.lua` (not a separate options file):

| Setting | Value | Notes |
|---------|-------|--------|
| `mapleader` | Space | Set before plugins |
| `number` / `relativenumber` | on | |
| `expandtab` / `shiftwidth` | true / 2 | |
| `wrap` | false | |
| `clipboard` | unnamedplus (unless SSH) | |
| `termguicolors` | true | |
| Folds | treesitter expr, level 99 | |

## Troubleshooting

### LSP not working

1. `:Mason` — install the server for the language
2. Restart Neovim
3. Check `:LspInfo` / `:checkhealth`

### Copilot not suggesting

1. `:Copilot auth`
2. `:Copilot status`
3. Confirm filetype is supported in `plugin/copilot.lua`

### Plugins not loading

1. Confirm `vim.pack.add` entries in `init.lua`
2. Check `nvim-pack-lock.json` and Neovim messages on startup
3. There is no `:Lazy` UI — this is not lazy.nvim

### Tmux navigation not working

- Neovim: `plugin/tmux.lua` loaded (vim-tmux-navigator in pack list)
- tmux: smart pane switching still present in `.tmux.conf`
