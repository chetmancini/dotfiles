# dotfiles

Personal dotfiles for macOS. Configuration for zsh, neovim, git, tmux, and various CLI tools.

> **Note**: These are my personal dotfiles. Feel free to read and take inspiration, but make your own edits - there's a lot of me-specific configuration here.

## Quick Start

```bash
# Clone to home directory
git clone https://github.com/chetmancini/dotfiles.git ~/dotfiles

# Run install script
cd ~/dotfiles
./install.sh

# Verify the installed state
doctor
```

## What's Included

| Tool | Config | Description |
|------|--------|-------------|
| zsh | `.zshrc` | Shell with oh-my-zsh, aliases, functions |
| neovim | `nvim/` | LazyVim-based config |
| git | `.gitconfig` | Aliases, delta pager, conventional commits |
| tmux | `.tmux.conf` | Terminal multiplexer |
| yazi | `yazi/` | File browser |
| ghostty | `ghostty/` | Terminal emulator |

## Homebrew Packages

All packages are managed via `Brewfile`:

```bash
# Install all packages
brew bundle --file=~/dotfiles/Brewfile

# See what would be installed
brew bundle check --file=~/dotfiles/Brewfile

# Update Brewfile from installed packages
brew bundle dump --file=~/dotfiles/Brewfile --force

# Remove packages not in Brewfile
brew bundle cleanup --file=~/dotfiles/Brewfile
```

### Categories in Brewfile

- **CLI Tools**: eza, bat, fzf, zoxide, jq, htop, yazi
- **Development**: neovim, gh, git-delta, awscli
- **Kubernetes**: kubectl, kubectx, k9s, helm
- **Languages**: pyenv, n, openjdk, bun
- **Databases**: postgresql, redis, sqlite
- **Apps**: Ghostty, Arc, Zed, JetBrains Toolbox, Slack, Discord
- **Fonts**: Monaspace, Hack (+ Nerd Font variants)

## Key Features

### Shell (zsh)
- Custom theme with git status (`chetmancini.zsh-theme`)
- Vi mode with visual cursor indicator
- Lazy-loaded pyenv and streamlined Node setup (`n`) for fast startup
- zoxide for smart directory jumping
- fzf integration for fuzzy finding

### Bootstrap
- `install.sh` supports interactive and headless installs (`--yes`, `--skip-brew`, etc.)
- `doctor` verifies symlinks, theme wiring, TPM, and repo health checks
- GitHub Actions smoke-tests the installer and doctor in a temporary `HOME`

### Git
- Conventional commit aliases: `git feat`, `git fix`, `git chore`, etc.
- Conditional includes for work vs personal repos
- git-delta for beautiful diffs

### Useful Aliases
```bash
gs          # git status -sb
ll          # eza with icons and git status
vi          # neovim
y           # yazi file browser (with cd on exit)
cd          # zoxide (smart directory jumping)
fzfp        # fzf with bat preview
```

## Adding New Tools

1. Add to `Brewfile`
2. Run `brew bundle`
3. If config needed, add symlink to `install.sh`
4. Add validation to `doctor`
5. Add any shell integration to `.zshrc`

## Structure

```
~/dotfiles/
├── .zshrc              # Main shell config
├── .gitconfig          # Git config (uses conditional includes)
├── .tmux.conf          # tmux config
├── Brewfile            # Homebrew packages
├── install.sh          # Setup script
├── chetmancini.zsh-theme  # Custom oh-my-zsh theme
├── bin/                # Custom scripts (see bin/README.md)
├── nvim/               # Neovim (LazyVim)
├── vim/                # Legacy Vim runtime
├── yazi/               # Yazi file browser
├── ghostty/            # Ghostty terminal
├── oh-my-zsh/          # Cloned install dependency
└── api_keys.sh         # API keys (gitignored)
```

## License

MIT - do whatever you want with it.

-Chet
