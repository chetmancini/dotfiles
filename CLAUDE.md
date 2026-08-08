# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for macOS/Linux environment configuration. The repository manages shell configuration (zsh), editor setups (vim, neovim), terminal multiplexer config (tmux), git configuration, and various utility scripts.

## Key Architecture

### Configuration Loading Flow

1. `.zshrc` is a thin orchestrator that resolves `DOTFILES_DIR` and sources modules from `zsh/`
2. Modules cover options, PATH, platform, theme, aliases, git helpers, functions, secrets, tools (fzf/zoxide/mise/completions), fun extras, then plugins last
3. Platform modules source `mac_specific.sh` or `linux_specific.sh`
4. Secrets modules source `api_keys.sh` / `api_keys_1password.sh` (gitignored; see templates)
5. Plugins (autosuggestions, history-substring-search, syntax-highlighting) load from Homebrew share paths

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
- `~/dotfiles/vim` → `~/.vim`
- `~/dotfiles/.gitconfig` → `~/.gitconfig`
- `~/dotfiles/.gitignore` → `~/.gitignore`
- `~/dotfiles/.zshrc` → `~/.zshrc`
- `~/dotfiles/.bashrc` → `~/.bashrc`
- `~/dotfiles/.bash_profile` → `~/.bash_profile`
- `~/dotfiles/.tmux.conf` → `~/.tmux.conf`
- `~/dotfiles/.vimrc` → `~/.vimrc`

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

# Preview the install without changing files
./install.sh --plan

# Headless/bootstrap mode
./install.sh --yes --skip-brew --no-clear

# Verify the installed state
doctor

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
- **Python**: Uses mise for version management, uv for fast package management
- **Node**: Uses mise for version management, with pnpm/bun as package managers
- **Ruby**: Uses rbenv for version management (currently commented out in zshrc)
- **Java**: OpenJDK with helper function `setjdk` to switch versions

## Important Files and Directories

- `.zshrc` - Thin shell orchestrator (sources `zsh/*.zsh`)
- `zsh/` - Modular shell config (aliases, git helpers, tools, plugins)
- `Brewfile` - Homebrew package manifest (formulae, casks, fonts)
- `install.sh` - Setup script for new machines
- `bin/doctor` - Installation verification script
- `chetmancini.zsh-theme` - Custom λ prompt theme
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
- `grom` - git rebase onto the remote's default branch (auto-detects main/master)
- `wt` / `wtl` / `wta` / `wtr` - git worktree / list / add / remove
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

- New shell aliases go in `zsh/aliases.zsh` or `zsh/git.zsh`; new tools get `zsh/tools/<name>.zsh` plus an orchestrator entry in `.zshrc`
- Plugins that wrap ZLE must load in `zsh/plugins.zsh` after custom widgets (syntax-highlighting last)
- API keys go in `api_keys.sh` (not tracked) - use `api_keys.sh.template` as reference
- When adding new tools, add them to `Brewfile` and run `brew bundle`
- If tools need config, add symlinks to `install.sh` and validation to `bin/doctor`
- Custom zsh theme uses lambda (λ) as prompt symbol with git status integration
- Editor is set to neovim globally (EDITOR env var and git core.editor)
- mise is the single runtime version manager (`zsh/tools/mise.zsh`); see `mise/config.toml`
- Optional cleanup: remove a leftover `~/dotfiles/oh-my-zsh` clone after confirming the shell works
