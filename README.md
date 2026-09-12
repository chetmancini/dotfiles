# dotfiles

Personal dotfiles for macOS and Linux (Arch/Omarchy). Configuration for zsh, neovim, git, tmux, and various CLI tools.

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

## Install profiles and Omarchy

Profiles are cumulative, and independent of interactive (`--yes`) or preview
(`--plan`) mode:

| Profile | Configuration | Packages |
|---------|---------------|----------|
| `minimal` | Git, zsh, tmux; Bash on macOS | Shell, Git/gh/delta, tmux, Python for doctor |
| `development` | Minimal + Neovim, Yazi, Atuin, mise, uv, npm, Herdr | Development CLI tools; no desktop casks |
| `desktop` | Development + Ghostty | Adds desktop packages/fonts |

macOS defaults to `desktop` and uses Homebrew. Linux defaults to `development`;
Arch/Omarchy uses the cumulative `packages/arch.*` lists with `pacman -S --needed`.
Other Linux distributions can install configurations but must provide packages
with their own package manager. The Arch list is a curated native subset of the
Mac Brewfile; vendor tools such as Herdr are installed separately when available.

```bash
# Omarchy: inspect exactly which existing configs would be replaced first
./install.sh --profile development --plan
./install.sh --profile development

# Small shell setup, or configuration only
./install.sh --profile minimal
./install.sh --profile development --skip-packages

# Explicitly take ownership of Ghostty config as well
./install.sh --profile desktop --plan
```

On Linux, Bash startup files are left intact to preserve Omarchy's integration.
Start `zsh` explicitly to use this shell setup; the installer does not change your
login shell. Development installs replace the selected app configs (including
Neovim), but leave Ghostty, Hyprland, and Omarchy's desktop/theme files alone.
Use `minimal` if you want to keep Omarchy's editor configuration too.
Existing regular files/directories are backed up; existing symlinks are replaced.

Keep Omarchy updated through its normal update workflow before installing packages.
The installer does not refresh pacman's databases, perform system upgrades, install
AUR packages, or change desktop defaults. Pacman retains its own confirmation prompt
and sudo authentication even with `--yes`. Use Omarchy's own terminal menu to select
your terminal ([Omarchy terminal documentation](https://omarchy.org/manual/terminal/)).

The selected profile is saved in `~/.config/dotfiles/profile`, so `doctor` (and
`status`) only require selected configs. Rerunning with a smaller profile does not
uninstall packages or remove existing links. `--plan` does not save state. Older
installs without a profile retain the historical full doctor checks.
`--skip-brew` remains an alias for skipping all package installation;
`--with-optional-brew` requires macOS desktop, and legacy Vim requires development
or desktop. `brew-sync` checks the selected Mac profile, refuses manifest rewrites
from partial profiles, and does not check Homebrew drift for native Linux installs.

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
- **Languages**: Mise (Node/Python runtimes), OpenJDK, Bun, uv, pnpm
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
- `status` provides fast, unified health checks across symlinks, repos, and Homebrew drift (`dot status` / `dot status --deep`)
- `dot` dispatches `bin/` tools (`dot help`, `dot status`, `dot doctor`, `dot brew-sync`, …); scripts also stay on PATH
- [`docs/package-managers.md`](docs/package-managers.md) defines the preferred owner for runtimes, native apps, and global JavaScript CLIs; use `package-sync --update` to refresh npm and pnpm globals
- GitHub Actions smoke-tests the installer and doctor in a temporary `HOME`
- `make format` formats shell scripts with `shfmt` and Lua files with `stylua`; `make check` runs formatting, syntax, ShellCheck, TOML, stylua, zsh checks, and bats tests (`tests/`)

### Secrets (1Password preferred)
- **Preferred:** copy `api_keys_1password.sh.template` → `api_keys_1password.sh` (gitignored), set `op://` item refs via `op_secret`
- Install 1Password CLI (`1password-cli` cask), enable app **Settings → Developer → Integrate with 1Password CLI**, unlock the app, check `op whoami`
- **Bootstrap only:** `api_keys.sh` from `api_keys.sh.template` for machines without 1Password
- Shell loads plaintext first, then 1Password (so 1P can override during migration) — see `zsh/secrets.zsh`
- Never commit real keys; never put secrets in tracked templates

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

See [`docs/package-managers.md`](docs/package-managers.md) before choosing an installer. One executable should have one preferred owner.

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
├── claude/             # Claude Code agents & commands (see docs/agents.md)
├── mcp.json.example    # MCP servers example (copy to mcp.json, gitignored)
├── plans/              # Implementation plans
├── docs/               # Extended documentation
├── api_keys_1password.sh.template  # Preferred secrets template
├── api_keys.sh.template            # Bootstrap plaintext template
└── api_keys*.sh                    # Live secrets (gitignored)
```

**Legacy**: `vim/` and `iterm/` remain in the repo for reference but are not required. Primary stack is Ghostty + Neovim. Pass `--with-legacy-vim` to symlink Vim config.

## License

MIT - do whatever you want with it.

-Chet
