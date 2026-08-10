# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for macOS/Linux environment configuration. The repository manages shell configuration (zsh), editor setups (vim, neovim), terminal multiplexer config (tmux), git configuration, and various utility scripts.

## Key Architecture

### Configuration Loading Flow

1. `.zshrc` is a thin orchestrator that resolves `DOTFILES_DIR` and sources modules from `zsh/`
2. Modules cover options, PATH, platform, theme, aliases, git helpers, functions, secrets, tools (fzf/zoxide/mise/direnv/atuin/completions), fun extras, then plugins last
3. Platform modules source `mac_specific.sh` or `linux_specific.sh`
4. Secrets (`zsh/secrets.zsh`): optional plaintext `api_keys.sh`, then preferred `api_keys_1password.sh` (both gitignored; templates tracked)
5. Tools include fzf, zoxide, mise, direnv, atuin (Ctrl-R); plugins (autosuggestions, history-substring-search, syntax-highlighting) load last from Homebrew

### Homebrew Package Management

Packages are split across two files:
- `Brewfile` — **core** daily CLI/dev stack (default `install.sh` brew step)
- `Brewfile.optional` — AI IDEs, messaging, heavy casks; install via `--with-optional-brew` or `brew bundle --file=Brewfile.optional`
- `brew-sync` checks drift against **core** only; optional packages are not treated as extras
- Organized by category: CLI tools, development, databases, casks, fonts

### Symlink-based Installation

The `install.sh` script creates symlinks from this repository to home directory:
- `~/dotfiles/yazi` → `~/.config/yazi`
- `~/dotfiles/ghostty` → `~/.config/ghostty`
- `~/dotfiles/nvim` → `~/.config/nvim`
- `~/dotfiles/atuin` → `~/.config/atuin`
- `~/dotfiles/.gitconfig` → `~/.gitconfig`
- `~/dotfiles/.gitignore` → `~/.gitignore`
- `~/dotfiles/.zshrc` → `~/.zshrc`
- `~/dotfiles/.bashrc` → `~/.bashrc`
- `~/dotfiles/.bash_profile` → `~/.bash_profile`
- `~/dotfiles/.tmux.conf` → `~/.tmux.conf`
- Legacy Vim (`.vimrc`, `vim` → `~/.vim`) is opt-in via `--with-legacy-vim`

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
brew bundle --file=~/dotfiles/Brewfile.optional   # optional profile
```

### Managing Brew Packages
```bash
# Core packages
brew bundle --file=~/dotfiles/Brewfile
brew bundle check --file=~/dotfiles/Brewfile

# Optional packages (AI IDEs, messaging, heavy casks)
brew bundle --file=~/dotfiles/Brewfile.optional

# Drift against core only (optional installs ignored as extras)
brew-sync                           # Check for drift
brew-sync --add                     # Add missing packages to core Brewfile
brew-sync --remove                  # Remove uninstalled packages from core Brewfile
brew-sync --update                  # Regenerate core Brewfile from installed packages
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
- `Brewfile` / `Brewfile.optional` - Core vs optional Homebrew manifests
- `install.sh` - Setup script for new machines
- `bin/doctor` - Installation verification script
- `chetmancini.zsh-theme` - Custom λ prompt theme
- `bin/` - Custom utility scripts (extract, imgcat, murder, removeexif, brew-sync, etc.)
- `nvim/` - Neovim config via `vim.pack` + `plugin/*.lua` (not LazyVim)
- `yazi/` - File browser configuration
- `ghostty/` - Ghostty terminal configuration
- `atuin/` - Atuin history-search config
- `api_keys_1password.sh.template` / `api_keys.sh.template` - Secrets stubs (prefer 1Password path)
- `api_keys*.sh` - Live secrets (gitignored; never commit)
- `plans/` - Modernization plans and status

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

Modular configuration in `nvim/` (no LazyVim / lazy.nvim):
- Entry point: `nvim/init.lua` — leaders, options, `vim.pack.add({...})`, colorscheme, core keymaps
- Feature modules: `nvim/plugin/*.lua` (lsp, completion, finder, git, format, rust, …)
- Lockfile: `nvim/nvim-pack-lock.json`
- Details: `docs/neovim.md`

## Notes for Modifications

- New shell aliases go in `zsh/aliases.zsh` or `zsh/git.zsh`; new tools get `zsh/tools/<name>.zsh` plus an orchestrator entry in `.zshrc`
- Plugins that wrap ZLE must load in `zsh/plugins.zsh` after custom widgets (syntax-highlighting last)
- Prefer API keys via `api_keys_1password.sh` + `op_secret` (template tracked; live file gitignored). Plaintext `api_keys.sh` is bootstrap-only.
- Daily tools → `Brewfile`; experimental/GUI → `Brewfile.optional`
- Legacy `vim/` and `iterm/` are kept in-repo but not installed by default
- If tools need config, add symlinks to `install.sh` and validation to `bin/doctor`
- Agent/MCP layout: `claude/agents/`, `claude/commands/`, `mcp.json.example` (see `docs/agents.md`; live `mcp.json` gitignored)
- Custom zsh theme uses lambda (λ) as prompt symbol with git status integration
- Editor is set to neovim globally (EDITOR env var and git core.editor)
- mise is the single runtime version manager (`zsh/tools/mise.zsh`); see `mise/config.toml`
- atuin owns Ctrl-R history search; direnv loads project `.envrc` after `direnv allow`
- Optional cleanup: remove a leftover `~/dotfiles/oh-my-zsh` clone if present (no longer used; removed in plan 002)
