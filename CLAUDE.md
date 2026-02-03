# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for macOS/Linux environment configuration. The repository manages shell configuration (zsh), editor setups (vim, neovim), terminal multiplexer config (tmux), git configuration, and various utility scripts.

## Key Architecture

### Configuration Loading Flow

1. `.zshrc` is the main entry point for shell configuration
2. Loads oh-my-zsh from `oh-my-zsh/` subdirectory (git submodule)
3. Sources platform-specific configs (`mac_specific.sh` or `linux_specific.sh`)
4. Sources `api_keys.sh` for environment variables (not tracked in git, see `api_keys.sh.template`)
5. Initializes various tools at the end: fzf, zoxide, pyenv, nvm, etc.

### Homebrew Package Management

Packages are managed via `Brewfile`:
- `brew bundle` installs all packages from Brewfile
- `brew bundle dump --force` updates Brewfile from installed packages
- `brew bundle cleanup` removes packages not in Brewfile
- Organized by category: CLI tools, development, databases, casks, fonts

### Symlink-based Installation

The `install.sh` script creates symlinks from this repository to home directory:
- `~/dotfiles/yazi` → `~/.config/yazi`
- `~/dotfiles/ghostty` → `~/.config/ghostty`
- `~/dotfiles/nvim` → `~/.config/nvim`
- `~/dotfiles/.gitconfig` → `~/.gitconfig`
- `~/dotfiles/.gitignore` → `~/.gitignore`
- `~/dotfiles/.zshrc` → `~/.zshrc`
- `~/dotfiles/.tmux.conf` → `~/.tmux.conf`

### Git Configuration Structure

- `.gitconfig` - Main git config with aliases and conditional includes
- `.gitconfig-personal` - Included for repos in `~/code/`
- `.gitconfig-work` - Included for repos in `~/norm/`
- Uses git-delta as the pager with side-by-side diffs
- Extensive conventional commit aliases (feat, fix, chore, etc.) with scope support

## Essential Commands

### Installation
```bash
# Initial setup (installs Homebrew packages and creates symlinks)
./install.sh

# Or install just brew packages
brew bundle --file=~/dotfiles/Brewfile
```

### Managing Brew Packages
```bash
# Install all packages from Brewfile
brew bundle --file=~/dotfiles/Brewfile

# Check what would be installed (dry run)
brew bundle check --file=~/dotfiles/Brewfile

# Update Brewfile from currently installed packages
brew bundle dump --file=~/dotfiles/Brewfile --force

# Remove packages not in Brewfile
brew bundle cleanup --file=~/dotfiles/Brewfile

# Check Brewfile drift (brew-sync)
brew-sync                           # Check for drift
brew-sync --add                     # Add missing packages to Brewfile
brew-sync --remove                  # Remove uninstalled packages from Brewfile
brew-sync --update                  # Regenerate Brewfile from installed packages
brew-sync --dry-run                 # Preview changes without applying
```

### Applying Changes
When modifying dotfiles, changes take effect in different ways:
- `.zshrc` changes: Run `source ~/.zshrc` or restart shell
- `.gitconfig` changes: Take effect immediately for new git commands
- Neovim config changes: Restart neovim
- Brewfile changes: Run `brew bundle --file=~/dotfiles/Brewfile`
- Symlink changes: Re-run the relevant `ln -s` command from `install.sh`

### Common Development Patterns

This repository includes configurations for:
- **Python**: Uses pyenv for version management, uv for fast package management
- **Node**: Uses nvm for version management, with pnpm/bun as alternatives to npm
- **Ruby**: Uses rbenv for version management (currently commented out in zshrc)
- **Java**: OpenJDK with helper function `setjdk` to switch versions

## Important Files and Directories

- `.zshrc` - Primary shell configuration with aliases, functions, and tool initialization
- `Brewfile` - Homebrew package manifest (formulae, casks, fonts)
- `install.sh` - Setup script for new machines
- `chetmancini.zsh-theme` - Custom oh-my-zsh theme
- `bin/` - Custom utility scripts (extract, imgcat, murder, removeexif, brew-sync, etc.)
- `nvim/` - LazyVim-based neovim configuration
- `yazi/` - File browser configuration
- `ghostty/` - Ghostty terminal configuration
- `api_keys.sh` - Environment variables and API keys (gitignored, template provided)

## Key Aliases and Functions

### Git Shortcuts
- `gs` - git status (short format)
- `gd` - git diff
- `gch` - git checkout
- `gaa` - git add -A
- `grom` - git rebase origin/main
- `cpbranch()` - Copy current branch name to clipboard

### Navigation
- `y()` - Launch yazi file browser with cd integration
- Uses zoxide for smart directory jumping (initialized if available)
- Uses fzf for fuzzy finding (initialized if available)

### Modern Replacements
- `ls` aliased to `eza --icons` (modern ls replacement)
- `vi` aliased to `nvim`
- `cat` → consider using `bat` (installed but not aliased)

## Neovim Configuration

LazyVim-based configuration located in `nvim/`:
- Entry point: `nvim/init.lua`
- Plugins defined in `nvim/lua/plugins/`
- Custom keymaps in `nvim/lua/config/keymaps.lua`
- Options in `nvim/lua/config/options.lua`

## Notes for Modifications

- The oh-my-zsh directory is a git submodule - don't edit files directly in it
- API keys go in `api_keys.sh` (not tracked) - use `api_keys.sh.template` as reference
- When adding new tools, add them to `Brewfile` and run `brew bundle`
- If tools need config, add symlinks to `install.sh`
- Custom zsh theme uses lambda (λ) as prompt symbol with git status integration
- Editor is set to neovim globally (EDITOR env var and git core.editor)
- nvm and pyenv are lazy-loaded for faster shell startup
