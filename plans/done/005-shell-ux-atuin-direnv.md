# Plan 005: Shell UX — atuin and direnv

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat a52b4b5..HEAD -- .zshrc zsh/ Brewfile bin/lib/symlinks.sh README.md`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW–MED (history binding conflicts with fzf/`^R`)
- **Depends on**: plan 002 strongly preferred (add `zsh/tools/atuin.zsh`, `zsh/tools/direnv.zsh`)
- **Category**: dx
- **Planned at**: commit `a52b4b5`, 2026-08-07

## Why this matters

History is large (`HISTSIZE=1000000`) but still file-based and local; search is
basic incremental/`history-substring-search`. Project-specific env currently
leans on global `api_keys*` and ad-hoc exports. **atuin** modernizes history
(SQLite, better search, optional sync). **direnv** loads project `.envrc`
safely and pairs well with mise and 1Password (`op inject`).

## Current state

- `.zshrc`: `^R` → `history-incremental-search-backward`; fzf zsh integration;
  zoxide owns `cd`; no atuin/direnv
- `Brewfile`: no atuin/direnv at plan time (confirm when executing)
- Secrets: plan 003 patterns

If 002 not merged, create modules anyway and source them from `.zshrc` as a
minimal two-line addition — but prefer 002 layout.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Check | `make check` | exit 0 |
| atuin | `atuin --version` | version prints after brew |
| direnv | `direnv version` | version prints |
| Zsh | `zsh -n` on modules | exit 0 |

## Scope

**In scope**:
- `Brewfile` (core): `atuin`, `direnv`
- New shell modules + orchestrator source lines
- Optional minimal configs: `atuin/` or XDG config if repo-managed; `direnv` rarely needs global config
- `bin/lib/symlinks.sh` only if committing atuin config into repo
- README short UX section
- Interaction with existing `^R` / fzf: document chosen binding

**Out of scope**:
- Forcing atuin account sync / login (operator opt-in)
- starship prompt migration
- Replacing zoxide
- Removing thefuck (optional one-line “consider removing” in docs only)

## Git workflow

- Branch: `advisor/005-atuin-direnv`
- Do NOT push/PR unless asked

## Steps

### Step 1: Add brew formulas

```ruby
brew "atuin"
brew "direnv"
```

Place under CLI tools section in **core** Brewfile (or post-004 core file).

**Verify**: formulas valid (`brew info atuin`, `brew info direnv`).

### Step 2: direnv module

Create `zsh/tools/direnv.zsh` (or `.zshrc` snippet):

```zsh
if command -v direnv &>/dev/null; then
  eval "$(direnv hook zsh)"
fi
```

Document in README: use `direnv allow` per project; never commit secrets in `.envrc` —
use `.envrc` + gitignored `.env` or `op inject`.

**Verify**: `zsh -ic 'type direnv'` shows function/hook after install.

### Step 3: atuin module — resolve `^R` conflict

Create `zsh/tools/atuin.zsh`:

```zsh
if command -v atuin &>/dev/null; then
  eval "$(atuin init zsh)"
fi
```

**Binding policy** (pick one, document in comments):

1. **Preferred**: Let atuin take `^R` (modern search). Keep fzf file widgets on
   Ctrl-T / Alt-C.
2. If operator must keep zsh incremental search: configure atuin to another
   binding per atuin docs (e.g. only up-arrow) — use `atuin init zsh` flags/docs
   at execution time via `atuin init zsh --help` or current upstream docs.

Load **after** other history keybinds so atuin wins, or remove obsolete
`bindkey '^R' history-incremental-search-backward` when atuin owns it.

**Verify**:

```bash
zsh -ic 'bindkey | rg "\\^R|atuin|history"' 2>/dev/null | head -20
```

### Step 4: Optional atuin config in repo

Only if you want shared defaults (not account secrets):

- e.g. `atuin/config.toml` with non-sensitive defaults (filter modes, enter behavior)
- Symlink via `symlinks.sh` to `~/.config/atuin/config.toml`

Skip sync tokens entirely.

**Verify**: no API keys in tracked atuin config.

### Step 5: Doctor optional commands

Add `atuin` and `direnv` to doctor’s soft command list (warnings, not failures).

**Verify**: `bin/doctor` warns if missing when `--skip-tools` is false.

### Step 6: Docs

README: 2–4 bullets on atuin history + direnv projects; binding choice; link to
`direnv allow` safety.

**Verify**: `rg -n 'atuin|direnv' README.md`.

### Step 7: make check + smoke

```bash
make check
# After brew install (operator machine):
# atuin import auto   # only if migrating history — ask before running
```

Do **not** run `atuin import` without noting it rewrites history DB — optional
operator step in Maintenance.

## Test plan

- Modules parse; brew formulas exist
- Interactive: `^R` opens atuin UI (or documented binding)
- Interactive: `cd` into dir with `.envrc` triggers direnv after `direnv allow`
- No regression: fzf Ctrl-T still works

## Done criteria

- [ ] atuin + direnv in core Brewfile
- [ ] shell hooks installed in modules / zshrc
- [ ] `^R` behavior documented and intentional
- [ ] doctor soft-checks the commands
- [ ] README updated
- [ ] `make check` exit 0
- [ ] `plans/README.md` 005 → DONE

## STOP conditions

- atuin init conflicts with zsh vi-mode widgets and breaks line editor after two
  fix attempts
- direnv hook causes non-interactive scripts to fail — ensure hook only in
  interactive zsh (standard direnv pattern)
- Brew formulas renamed/unavailable — stop and report alternatives

## Maintenance notes

- Project env: prefer `.envrc` + mise; secrets via `op inject` / 1P (plan 003)
- Reviewers: keybind section carefully
- Optional later: remove `thefuck` lazy wrapper if atuin + CORRECT suffice
