# Plan 004: Prune legacy surface and split Brewfile profiles

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat a52b4b5..HEAD -- Brewfile bin/lib/symlinks.sh install.sh bin/doctor bin/brew-sync README.md .zshrc zsh/ iterm/ vim/ .vimrc`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (removing brew packages / symlinks can surprise daily use)
- **Depends on**: plan 002 (shell no longer needs OMZ); plan 001 preferred for brew language stack
- **Category**: tech-debt
- **Planned at**: commit `a52b4b5`, 2026-08-07

## Why this matters

The tree still carries **iTerm** prefs, **legacy Vim** runtime/pathogen, PATH
entries for long-dead prefixes, and a **single Brewfile** that mixes core CLI
tools with a large optional app surface (Adobe, multiple AI IDEs, messaging).
New machines get a heavy install; docs still describe old stacks. Pruning and
profiling makes bootstrap intentional without deleting the operator’s taste.

## Current state

- `bin/lib/symlinks.sh` still installs `.vimrc`, `vim` → `~/.vim`
- `iterm/com.googlecode.iterm2.plist` present while Ghostty is primary terminal
- `Brewfile` ~186 lines: core CLI + k8s + languages + many casks
- `.zshrc` PATH still mentions historical locations (`MYSQL_HOME`,
  `/usr/local/share/npm/bin`, memcached aliases under `/usr/local`)
- README lists languages as pyenv/`n` (may already be fixed by 001)

Symlink home group excerpt:

```bash
.vimrc|.vimrc|Vim Configuration|...
vim|.vim|Vim Runtime|Legacy Vim runtime files, including colors and pathogen
```

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Check | `make check` | exit 0 |
| Brew dry | `brew bundle check --file=Brewfile` | useful status (may be non-zero if missing pkgs) |
| Doctor | `bin/doctor` | matches new symlink policy |
| Install plan | `./install.sh --plan --skip-brew` | lists intended symlinks only |

## Scope

**In scope**:
- `Brewfile` → split into `Brewfile` (core) + `Brewfile.optional` (or `brew/Brewfile.*`)
- `bin/lib/symlinks.sh` — vim/iterm policy
- `install.sh` — optional bundle step; vim symlink prompts
- `bin/doctor` — align checks
- `bin/brew-sync` — only if it hardcodes a single Brewfile path; update to understand core vs optional **minimally**
- `.zshrc` or `zsh/path.zsh` / aliases — remove dead PATH and memcached aliases if unused
- `README.md` — document brew profiles
- Mark `iterm/` and `vim/` as legacy in README (delete from git only if operator-confirm step passes)

**Out of scope**:
- `brew uninstall` mass removal of casks already on the machine
- Rewriting neovim config
- mac_dev_install.sh full rewrite (optional light comment only)
- Plan 008 full docs rewrite beyond brew/legacy sections

## Git workflow

- Branch: `advisor/004-prune-legacy-brewfile`
- Commits: `chore: split Brewfile optional profile`, `chore: stop installing legacy vim by default`, etc.
- Do NOT push/PR unless asked

## Steps

### Step 1: Inventory and classify Brewfile packages

Read full `Brewfile`. Classify each entry:

| Tier | Meaning |
|------|---------|
| **core** | Needed for documented daily shell/dev workflow |
| **optional** | Nice-to-have apps, extra AI IDEs, heavy casks |
| **remove** | Clearly obsolete or duplicated (e.g. if 001 removed pyenv/`n`) |

Suggested **optional** movers (executor may adjust with comment in PR):

- Heavy casks: `adobe-creative-cloud`, `mactex`, multiple chat apps if not essential
- Overlapping AI editors beyond what operator considers daily (do **not** gut all AI tools — move extras to optional, keep Ghostty/1password-cli/core CLIs in main)
- Fun-only: `cmatrix`, `gti` if operator agrees — default: move `cmatrix` to optional, keep small fun formulas if tiny

Suggested **core** keepers:

- Modern CLI: bat, eza, fd, fzf, ripgrep, zoxide, yazi, tmux, neovim, git-delta, gh, jq, shellcheck, shfmt, mise, uv, zsh plugin formulas
- Ghostty, 1password-cli

**Verify**: Write the two files such that every former package appears in exactly one file (or is intentionally deleted with a comment in the commit message).

### Step 2: Create `Brewfile.optional` and slim `Brewfile`

1. Create `Brewfile.optional` with a header comment:

```ruby
# Optional packages — install with:
#   brew bundle --file=~/dotfiles/Brewfile.optional
# Not installed by default install.sh brew step.
```

2. Move optional lines out of `Brewfile`.
3. Keep taps required by optional packages **in the optional file** (or duplicate taps safely).

**Verify**:

```bash
test -f Brewfile && test -f Brewfile.optional
# No duplicate brew lines across files (rough check)
comm -12 <(grep -E '^brew |^cask ' Brewfile | sort) <(grep -E '^brew |^cask ' Brewfile.optional | sort) || true
# empty intersection preferred
```

### Step 3: Wire install.sh

After core `brew bundle --file=Brewfile`:

- Ask (or `--yes` policy): “Install optional Brew packages?” default **No** for `--yes` headless to keep CI/bootstrap light.
- Add flag `--with-optional-brew` to opt in headless.

**Verify**: `./install.sh --help` shows the flag; `--plan --skip-brew` still works.

### Step 4: Legacy Vim / iTerm policy

**Default (safe)**:

1. Remove `vim` and `.vimrc` from **default** symlink group OR gate behind `ask_yes_no "Install legacy Vim runtime?"` default No.
2. Do **not** delete `vim/` or `iterm/` from the repo in the same step unless operator set env `DOTFILES_DELETE_LEGACY=1`.
3. README: “Legacy: `vim/`, `iterm/` — not installed by default; Ghostty + nvim are primary.”

**If operator confirmation is available in-session** and they want deletion:

- Only then `git rm` iterm plist / vim runtime — prefer separate commit.

**Verify**: `./install.sh --plan` does not list Vim as required; doctor doesn’t fail if `~/.vim` missing.

### Step 5: Dead PATH and aliases

In path/aliases modules:

- Remove or comment `MYSQL_HOME`, obsolete `NPM_PATH=/usr/local/share/npm/bin` if unused
- Remove `start_memcached` / `stop_memcached` if paths don’t exist on modern brew
- Keep `path_add` existence checks so residual vars are harmless if left temporarily

**Verify**: `zsh -n` on shell files; `prettypath` or `echo $PATH` doesn’t need to change drastically.

### Step 6: brew-sync compatibility

Read `bin/brew-sync` header/options. If it assumes single Brewfile:

- Default sync against **core** `Brewfile`
- Document that optional packages won’t be “drift-removed” from the machine automatically
- Avoid destructive cleanup across optional set

**Verify**: `bin/brew-sync --help` or dry-run still exits 0.

### Step 7: Docs + doctor

- README Homebrew section: core vs optional commands
- doctor: don’t require optional casks

**Verify**: `make check`; `bin/doctor --skip-tools`.

## Test plan

- CI `make check` still green (no brew install in CI required)
- Local: `brew bundle check --file=Brewfile` for core
- Manual: optional file installs with explicit command
- Symlink plan mode no longer forces vim

## Done criteria

- [ ] `Brewfile` is core-only; `Brewfile.optional` exists and is documented
- [ ] install.sh installs core by default; optional is opt-in
- [ ] Legacy vim not required for healthy doctor on nvim-only setup
- [ ] iTerm/vim documented as legacy (removed from repo only if explicitly approved)
- [ ] Dead memcached/mysql path cruft reduced
- [ ] `make check` exit 0
- [ ] `plans/README.md` 004 → DONE

## STOP conditions

- `brew-sync --remove` logic would uninstall optional apps unexpectedly — stop and narrow scope
- Operator still daily-drives iTerm or Vim and needs default symlinks — keep gates, don’t delete
- Split would break a documented `mac_dev_install.sh` assumption — update or stop

## Maintenance notes

- New daily CLI → core Brewfile; new GUI experiment → optional
- Reviewers: check CI doesn’t try to bundle optional
- Follow-up: plan 008 docs; consider mas App Store list separately
