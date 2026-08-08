# Dotfiles Documentation

Personal dotfiles for macOS development environment.

## Quick Start

```bash
git clone https://github.com/chetmancini/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --plan
./install.sh
doctor
# or: dot doctor
```

## Applications

| App | Description | Config |
|-----|-------------|--------|
| [tmux](./tmux.md) | Terminal multiplexer with vim integration | `.tmux.conf` |
| [neovim](./neovim.md) | Modular Neovim (`vim.pack` + `plugin/*.lua`) | `nvim/` |
| [yazi](./yazi.md) | Terminal file browser with git integration | `yazi/` |
| [ghostty](./ghostty.md) | GPU-accelerated terminal | `ghostty/` |
| [bin scripts](./bin.md) | Utility scripts (`dot help` to discover) | `bin/` |

## Tool Integration

```
                    +-----------+
                    |  ghostty  |
                    +-----+-----+
                          |
                    +-----v-----+
            +------>|   tmux    |<------+
            |       +-----+-----+       |
            |             |             |
     +------+------+      |      +------+------+
     | vim-tmux-   |      |      | fzf session |
     | navigator   |      |      | switching   |
     +------+------+      |      +-------------+
            |             |
            |       +-----v-----+
            +------>|  neovim   |
                    +-----+-----+
                          |
          +---------------+---------------+
          |               |               |
    +-----v-----+   +-----v-----+   +-----v-----+
    |  copilot  |   |   mason   |   |   yazi    |
    +-----------+   +-----------+   +-----------+
```

Key integrations:
- **ghostty + tmux**: Transparent terminal with tmux sessions
- **tmux + neovim**: Seamless pane/split navigation with `Ctrl-h/j/k/l`
- **neovim + Copilot**: AI-assisted coding
- **yazi + neovim**: File browser launches in `$EDITOR`
- **zsh + mise/atuin/direnv**: versions, history search, project env

## File Structure

```
~/dotfiles/
├── .zshrc                 # Thin shell orchestrator
├── zsh/                   # Modular shell config
├── .tmux.conf
├── .gitconfig
├── Brewfile               # Core Homebrew packages
├── Brewfile.optional      # Optional apps/tools
├── install.sh
├── chetmancini.zsh-theme  # Custom λ prompt (no oh-my-zsh)
├── nvim/                  # Neovim (vim.pack)
├── atuin/                 # Atuin config (history search)
├── vim/                   # Legacy Vim (not installed by default)
├── iterm/                 # Legacy iTerm prefs
├── yazi/
├── ghostty/
├── bin/                   # Utility scripts + `dot` dispatcher
├── plans/                 # Modernization / implementation plans
└── docs/                  # This documentation
```

## Installation Details

`install.sh` creates symlinks (see `bin/lib/symlinks.sh` for the full list).
Core defaults include:

| Source | Target |
|--------|--------|
| `~/dotfiles/yazi` | `~/.config/yazi` |
| `~/dotfiles/ghostty` | `~/.config/ghostty` |
| `~/dotfiles/nvim` | `~/.config/nvim` |
| `~/dotfiles/mise` | `~/.config/mise` |
| `~/dotfiles/uv` | `~/.config/uv` |
| `~/dotfiles/atuin` | `~/.config/atuin` |
| `~/dotfiles/.gitconfig` | `~/.gitconfig` |
| `~/dotfiles/.zshrc` | `~/.zshrc` |
| `~/dotfiles/.tmux.conf` | `~/.tmux.conf` |

Legacy Vim (`.vimrc` / `vim` → `~/.vim`) is **opt-in** via `./install.sh --with-legacy-vim`.

Homebrew:

```bash
brew bundle --file=~/dotfiles/Brewfile
brew bundle --file=~/dotfiles/Brewfile.optional   # optional apps
```

Validate:

```bash
doctor
# or
dot doctor
dot help
```

## Applying Changes

| Config | How to apply |
|--------|--------------|
| `.zshrc` / `zsh/` | `source ~/.zshrc` or restart shell |
| `.gitconfig` | Immediate (new commands) |
| Neovim | Restart neovim |
| Core Brewfile | `brew bundle --file=~/dotfiles/Brewfile` |
| Optional Brewfile | `brew bundle --file=~/dotfiles/Brewfile.optional` |

## Plans

Implementation / modernization notes live in [`plans/`](../plans/) (mise, modular zsh, Brewfile profiles, atuin/direnv, `dot` CLI, docs, etc.).
