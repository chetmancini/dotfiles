# Plan 001: Consolidate version managers onto mise

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat a52b4b5..HEAD -- .zshrc Brewfile mise/ README.md CLAUDE.md bin/doctor install.sh`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: migration
- **Planned at**: commit `a52b4b5`, 2026-08-07

## Why this matters

The shell currently activates **three** overlapping version-manager stories:
lazy **nvm**, lazy **pyenv**, brew formula **n**, plus **mise** already in
`Brewfile` and activated at the bottom of `.zshrc` with an **empty**
`mise/config.toml`. That means duplicate PATH entries, conflicting Node
binaries, and docs that contradict each other (README says `n` + pyenv;
CLAUDE.md says nvm + pyenv; zshrc has nvm + pyenv + mise).

Consolidating onto mise gives one activation path, project-local tool pinning
via `mise.toml` / `.tool-versions`, and lets later plans delete nvm/pyenv
shims from the modular shell.

## Current state

Relevant files:

- `.zshrc` — main shell config; PATH build, lazy pyenv/nvm, mise activate
- `mise/config.toml` — **empty file** (symlink target via `~/.config/mise`)
- `Brewfile` — installs `mise`, `pyenv`, `n`, `bun`, `pnpm`, `uv`
- `bin/lib/symlinks.sh` — links `mise` → `~/.config/mise`
- `README.md` / `CLAUDE.md` — document pyenv/nvm/`n` as primary

Excerpts as of `a52b4b5`:

```zsh
# .zshrc (~590–629)
# Lazy-load pyenv (saves ~100ms on shell startup)
pyenv() {
  unset -f pyenv
  eval "$(command pyenv init -)"
  pyenv "$@"
}

# Lazy-load nvm (saves ~200ms on shell startup)
export NVM_DIR="$HOME/.nvm"
if [ -d "$NVM_DIR" ]; then
  nvm() { ... source nvm.sh ... }
  node() { ... }
  npm() { ... }
  npx() { ... }
fi

# Mise
if command -v mise &> /dev/null; then
  eval "$(mise activate zsh)"
fi
```

```toml
# mise/config.toml — file exists but is empty
```

```ruby
# Brewfile
brew "mise"
brew "pyenv"
brew "n"
brew "oven-sh/bun/bun"
brew "pnpm"
brew "uv"
```

```bash
# bin/lib/symlinks.sh (config group)
mise|.config/mise|Mise|Mise config|Dev tool version manager with trusted config paths for ~/norm, ~/projects, ~/code
```

**Conventions**: Prefer explicit over implicit; keep shell startup fast; only add
PATH entries when dirs exist (`path_add` in `.zshrc`). Do not commit secrets.
Match commit style: short imperative subjects (`fix npm global prefix`,
`Deduplicate git aliases (#42)`).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Syntax/lint | `make check` | exit 0 |
| Doctor | `doctor` or `bin/doctor` | exit 0 (warnings OK unless introduced by this plan) |
| Mise present | `command -v mise && mise --version` | prints version |
| Mise trust/config | `mise doctor` | no fatal errors about missing config |
| Zsh parse | `zsh -n .zshrc` | exit 0 |
| Node after change | `zsh -ic 'which node; node --version'` | path under mise/shims or mise install dir, not only `~/.nvm` |
| Python after change | `zsh -ic 'which python3; python3 --version'` | sensible system or mise python |

## Scope

**In scope**:
- `mise/config.toml`
- `.zshrc` (version-manager sections and related PATH/env only)
- `Brewfile` (comment/move `n` and `pyenv` off the default critical path; see steps)
- `README.md` language-version sections only
- `CLAUDE.md` Python/Node/tool-init bullets only
- `bin/doctor` only if a mise-specific check needs tightening

**Out of scope**:
- Full `.zshrc` modularization (plan 002)
- Removing oh-my-zsh (plan 002)
- Deleting the user’s existing `~/.nvm` or `~/.pyenv` directories on disk
- Changing uv config under `uv/`
- Installing global language versions without documenting defaults
- Brewfile optional-profile split (plan 004)

## Git workflow

- Branch: `advisor/001-mise-consolidation`
- Commits: small logical units, e.g. `feat: seed mise config`, `refactor: drop nvm/pyenv shims for mise`
- Do NOT push or open a PR unless the operator instructs it

## Steps

### Step 1: Drift check and inventory

Run the drift check from the executor header. Inventory what the machine
currently provides (read-only):

```bash
command -v mise; mise --version 2>/dev/null || true
command -v n; command -v pyenv; command -v nvm 2>/dev/null || true
ls -la ~/.nvm 2>/dev/null | head -3 || true
ls -la ~/.pyenv 2>/dev/null | head -3 || true
ls -la ~/.config/mise 2>/dev/null || true
readlink ~/.config/mise 2>/dev/null || true
```

Record results in the PR/commit body if useful. Do not delete `~/.nvm`/`~/.pyenv`.

**Verify**: `test -f mise/config.toml` → file exists (may be empty).

### Step 2: Seed `mise/config.toml`

Write a real config that:

1. Sets sensible defaults for this repo’s intended global tools.
2. Documents trusted/config paths if mise supports them for project dirs
   (`~/code`, `~/norm`, `~/projects` — already mentioned in symlink description).

Recommended starting content (adjust versions to whatever `mise latest node`
/ `mise latest python` report at execution time — **do not invent ancient
versions**):

```toml
# ~/.config/mise/config.toml (repo: mise/config.toml)

[settings]
# Prefer idiomatic version files in projects
idiomatic_version_file_enable_tools = ["node", "python"]

# Optional: experimental features only if needed — leave off unless required

[tools]
# Pin globals deliberately. Executor: run `mise latest node` and `mise latest python`
# and fill concrete versions, e.g.:
# node = "22.14.0"
# python = "3.13.2"
```

If the operator’s machine already has preferred versions, use those:

```bash
mise latest node
mise latest python
```

Also add a short comment at the top of the file:

```toml
# Managed by ~/dotfiles (symlinked to ~/.config/mise).
# Project-local overrides: put mise.toml or .tool-versions in the project root.
# Package managers: use uv (Python packages), pnpm/bun (JS) — not mise plugins for npm CLIs.
```

**Verify**:

```bash
# After symlink exists (doctor / install); if not linked, mise may still read via MISE_CONFIG or default
cat mise/config.toml | head -20
# File is non-empty
test -s mise/config.toml
```

### Step 3: Install tools via mise (local machine only)

```bash
mise install
mise use --global node@<version from step 2>
mise use --global python@<version from step 2>
# or rely on [tools] in config.toml + `mise install`
mise ls
```

**Verify**: `mise which node` and `mise which python` (or `python3`) print paths
under mise’s data dir/shims. Exit 0.

If `mise install` fails due to network/sandbox, STOP and report — do not fake versions.

### Step 4: Prefer mise in `.zshrc`; retire nvm/pyenv lazy shims

Edit `.zshrc`:

1. **Keep** `PYENV_ROOT` removal only if nothing else needs it — after this plan,
   remove `export PYENV_ROOT=...` and `path_add "$PYENV_ROOT/bin"` if present
   and unused.
2. **Delete** the entire lazy-load blocks for `pyenv` and `nvm`/`node`/`npm`/`npx`
   (approx. lines 590–620).
3. **Keep** mise activation, but move it **earlier** relative to tools that need
   node/python on PATH for interactive use — still after PATH is built, before
   or after compinit is fine; do **not** run slow `mise install` on every shell.
4. Ensure only **one** activation:

```zsh
# Version managers — mise is the single runtime manager (node, python, …).
# Package managers stay separate: uv, pnpm, bun.
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi
```

5. Leave **bun** completions and **pnpm** PATH as-is (package managers, not version managers).
6. Do **not** remove brew `n` from the machine yet — only stop depending on it in zsh.

**Verify**:

```bash
zsh -n .zshrc
# Interactive smoke (may need full login env)
zsh -ic 'command -v mise; type node; type python3' 2>/dev/null | head -20
# Confirm nvm function is gone
zsh -ic 'type nvm' 2>&1 | grep -qi 'not found\|none' && echo 'nvm unset OK' || echo 'CHECK nvm still defined'
```

Expected: `mise` found; `node` resolves without sourcing `~/.nvm/nvm.sh`.

### Step 5: Brewfile — demote pyenv and n

In `Brewfile`:

- Keep `brew "mise"`, `brew "uv"`, `brew "pnpm"`, `brew "oven-sh/bun/bun"`.
- Comment out or remove `brew "pyenv"` and `brew "n"` with a comment:

```ruby
# Version management is mise (see mise/config.toml). Historical alternatives:
# brew "pyenv"
# brew "n"
```

Do **not** run `brew uninstall` unless the operator asks. Optional packages
can remain installed on the machine.

**Verify**: `grep -E 'pyenv|^brew "n"' Brewfile` shows only comments (or no hits).

### Step 6: Docs touch (minimal)

Update these bullets only (full docs pass is plan 008):

- `README.md`: Languages / shell sections — say **mise** for Node/Python versions;
  **uv** for Python packages; **pnpm/bun** for JS packages. Remove “lazy pyenv” / primary `n` claims.
- `CLAUDE.md`: same for Python/Node notes and “nvm and pyenv are lazy-loaded”.

**Verify**:

```bash
rg -n 'lazy-load(ed)? (nvm|pyenv)|Uses nvm|Uses pyenv' README.md CLAUDE.md || echo 'clean'
rg -n 'mise' README.md CLAUDE.md
```

### Step 7: Verification suite

```bash
make check
bin/doctor --skip-tools || bin/doctor
zsh -n .zshrc
```

**Verify**: `make check` exit 0. Doctor does not fail on new errors introduced here
(existing warnings OK).

## Test plan

This repo has no unit tests for zsh. Characterization checks:

1. `zsh -n .zshrc` — parse OK
2. `make zsh-check` — includes `.zshrc`
3. Manual: new shell shows `mise` active; `which node` not under `~/.nvm` if mise node installed
4. Optional: create a temp dir with `echo 'node 20' > .tool-versions` and confirm
   `mise` picks it up when cd’d (document result in commit message)

No new test files required unless you add a tiny script under `scripts/` — prefer not to.

## Done criteria

- [ ] `mise/config.toml` is non-empty and defines tools and brief usage comments
- [ ] `.zshrc` has no nvm/pyenv lazy-load functions; has single `mise activate`
- [ ] `Brewfile` no longer actively requires `pyenv` or `n` as first-class installs
- [ ] `README.md` + `CLAUDE.md` no longer claim nvm/pyenv as the primary version managers
- [ ] `make check` exits 0
- [ ] `zsh -n .zshrc` exits 0
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row for 001 → DONE

## STOP conditions

Stop and report if:

- Drift check shows `.zshrc` version-manager section already rewritten differently
- `mise` is not installed and cannot be installed (`brew install mise` fails)
- Operator’s workflow **requires** nvm-specific tooling (e.g. `nvm use` in team docs) and no mise equivalent works — report rather than force-migrate
- Removing pyenv breaks a non-dotfiles project hook you discover mid-change (note path and stop)
- `make check` fails for reasons unrelated and unfixable within scope

## Maintenance notes

- New languages: add to `mise/config.toml` `[tools]`, not new lazy shims in zsh.
- Project pins: prefer committed `mise.toml` in apps under `~/code` / `~/norm`.
- Reviewers should check PATH order: brew vs mise shims (mise activate usually prepends shims).
- Deferred: uninstalling leftover `~/.nvm` / pyenv versions (operator hygiene).
- Next plan (002) will relocate the mise snippet into `zsh/tools/mise.zsh`.
