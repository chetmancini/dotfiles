# Dotfiles Documentation

Personal dotfiles for macOS development environment.

## Quick Start

```bash
git clone https://github.com/chetmancini/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --plan
./install.sh
doctor
```

## Applications

| App | Description | Config |
|-----|-------------|--------|
| [tmux](./tmux.md) | Terminal multiplexer with vim integration | `.tmux.conf` |
| [neovim](./neovim.md) | LazyVim-based editor with 40+ plugins | `nvim/` |
| [yazi](./yazi.md) | Terminal file browser with git integration | `yazi/` |
| [ghostty](./ghostty.md) | GPU-accelerated terminal | `ghostty/` |
| [bin scripts](./bin.md) | Utility scripts for daily workflows | `bin/` |

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
- **ghostty + tmux**: Transparent terminal with tmux quick-toggle
- **tmux + neovim**: Seamless pane/split navigation with `Ctrl-h/j/k/l`
- **neovim + Copilot**: AI-assisted coding with auto-suggestions
- **yazi + neovim**: File browser launches in `$EDITOR`

## File Structure

```
~/dotfiles/
├── .zshrc              # Shell configuration
├── .tmux.conf          # Tmux configuration
├── .gitconfig          # Git configuration
├── Brewfile            # Homebrew packages
├── install.sh          # Setup script
├── chetmancini.zsh-theme  # Custom oh-my-zsh theme
├── nvim/               # Neovim (LazyVim)
├── vim/                # Legacy Vim runtime
├── yazi/               # Yazi file browser
├── ghostty/            # Ghostty terminal
├── bin/                # Utility scripts
└── docs/               # This documentation
```

## Installation Details

The `install.sh` script creates symlinks:

| Source | Target |
|--------|--------|
| `~/dotfiles/yazi` | `~/.config/yazi` |
| `~/dotfiles/ghostty` | `~/.config/ghostty` |
| `~/dotfiles/nvim` | `~/.config/nvim` |
| `~/dotfiles/vim` | `~/.vim` |
| `~/dotfiles/.gitconfig` | `~/.gitconfig` |
| `~/dotfiles/.gitignore` | `~/.gitignore` |
| `~/dotfiles/.zshrc` | `~/.zshrc` |
| `~/dotfiles/.bashrc` | `~/.bashrc` |
| `~/dotfiles/.bash_profile` | `~/.bash_profile` |
| `~/dotfiles/.tmux.conf` | `~/.tmux.conf` |
| `~/dotfiles/.vimrc` | `~/.vimrc` |
| `~/dotfiles/chetmancini.zsh-theme` | `~/dotfiles/oh-my-zsh/custom/themes/chetmancini.zsh-theme` |

Homebrew packages are installed via:
```bash
brew bundle --file=~/dotfiles/Brewfile
```

Validate the installed state with:
```bash
doctor
```

## Applying Changes

| Config | How to apply |
|--------|--------------|
| `.zshrc` | `source ~/.zshrc` or restart shell |
| `.gitconfig` | Immediate (new commands) |
| Neovim | Restart neovim |
| Brewfile | `brew bundle --file=~/dotfiles/Brewfile` |
