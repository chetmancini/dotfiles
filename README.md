# dotfiles

Personal dotfiles for macOS. Configuration for zsh, neovim, git, tmux, and various CLI tools.

> **Note**: These are my personal dotfiles. Feel free to read and take inspiration, but make your own edits - there's a lot of me-specific configuration here.

## Quick Start

```bash
# Clone to home directory
git clone https://github.com/chetmancini/dotfiles.git ~/dotfiles

# Run install script
cd ~/dotfiles
./install.sh --plan
./install.sh

# Verify the installed state
doctor
```

## What's Included

| Tool | Config | Description |
|------|--------|-------------|
| zsh | `.zshrc` + `zsh/` | Modular shell (aliases, functions, tools) |
| neovim | `nvim/` | Modular config (`vim.pack` + `plugin/*.lua`) |
| git | `.gitconfig` | Aliases, delta pager, conventional commits |
| tmux | `.tmux.conf` | Terminal multiplexer |
| yazi | `yazi/` | File browser |
| ghostty | `ghostty/` | Terminal emulator |

## Homebrew Packages

Packages are split into **core** and **optional** profiles:

| File | Purpose | Default install |
|------|---------|-----------------|
| `Brewfile` | Daily CLI, languages, k8s, Ghostty, fonts | Yes (`install.sh` / `brew bundle`) |
| `Brewfile.optional` | AI IDEs, messaging, heavy casks, fun extras | Opt-in |

```bash
# Core (default)
brew bundle --file=~/dotfiles/Brewfile
brew bundle check --file=~/dotfiles/Brewfile

# Optional apps/tools
brew bundle --file=~/dotfiles/Brewfile.optional

# Via install.sh
./install.sh --yes --skip-brew          # no brew
./install.sh --with-optional-brew       # core + optional
./install.sh --with-legacy-vim          # also symlink legacy Vim

# Drift against core only (optional packages ignored as "extras")
brew-sync
```

### Core categories

- **CLI Tools**: eza, bat, fzf, zoxide, atuin, direnv, jq, htop, yazi, shellcheck, shfmt
- **Development**: neovim, gh, git-delta, awscli, mise
- **Kubernetes**: kubectl, kubectx, k9s, helm
- **Languages**: mise (node/python), openjdk, bun, uv, pnpm
- **Databases**: postgresql, redis, sqlite
- **Apps**: Ghostty, 1Password CLI
- **Fonts**: Monaspace, Hack (+ Nerd Font variants)

Optional includes AI apps (Claude, Cursor, Zed, …), messaging, Adobe, MacTeX, etc.

## Key Features

### Shell (zsh)
- Thin `.zshrc` orchestrator sourcing modules under `zsh/`
- Custom theme with git status (`chetmancini.zsh-theme`)
- Homebrew zsh plugins: autosuggestions, history-substring-search, syntax-highlighting
- Vi mode with visual cursor indicator
- **mise** for Node/Python versions (see `mise/config.toml`); **uv** / **pnpm** / **bun** for packages
- zoxide for smart directory jumping
- fzf integration for fuzzy finding (Ctrl-T files, Alt-C dirs)
- **atuin** for shell history search (**Ctrl-R**); up-arrow stays history-substring
- **direnv** for per-project env (`.envrc` + `direnv allow`; never commit secrets)

### Bootstrap
- `install.sh` supports interactive, preview, and headless installs (`--plan`, `--yes`, `--skip-brew`, `--with-optional-brew`, `--with-legacy-vim`, etc.)
- `doctor` verifies core symlinks, zsh modules, TPM, and repo health checks (legacy Vim not required)
- `dot` dispatches `bin/` tools (`dot help`, `dot doctor`, `dot brew-sync`, …); scripts also stay on PATH
- GitHub Actions smoke-tests the installer and doctor in a temporary `HOME`
- `make format` formats shell scripts with `shfmt`; `make check` runs formatting, syntax, ShellCheck, TOML, and zsh checks

### Git
- Conventional commit aliases: `git cc <type>`, `git feat`, `git fix`, `git chore`, etc.
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

1. Daily CLI → `Brewfile`; experimental/GUI apps → `Brewfile.optional`
2. Run `brew bundle --file=…` for the right profile
3. If config needed, add symlink to `bin/lib/symlinks.sh` (+ install/doctor)
4. Add any shell integration under `zsh/` (and one line in `.zshrc` if a new module)

## Structure

```
~/dotfiles/
├── .zshrc              # Thin shell orchestrator
├── zsh/                # Modular shell config (aliases, tools, plugins)
├── .gitconfig          # Git config (uses conditional includes)
├── .tmux.conf          # tmux config
├── Brewfile            # Core Homebrew packages
├── Brewfile.optional   # Optional apps/tools (opt-in)
├── install.sh          # Setup script
├── chetmancini.zsh-theme  # Custom λ theme
├── bin/                # Custom scripts + `dot` (see bin/README.md)
├── nvim/               # Neovim (vim.pack + plugin/*.lua)
├── atuin/              # Atuin history config
├── vim/                # Legacy Vim runtime (not installed by default)
├── iterm/              # Legacy iTerm prefs (Ghostty is primary)
├── yazi/               # Yazi file browser
├── ghostty/            # Ghostty terminal
├── plans/              # Implementation plans
├── docs/               # Extended documentation
└── api_keys.sh         # API keys (gitignored)
```

**Legacy**: `vim/` and `iterm/` remain in the repo for reference but are not required. Primary stack is Ghostty + Neovim. Pass `--with-legacy-vim` to symlink Vim config.

## License

MIT - do whatever you want with it.

-Chet
