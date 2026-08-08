# Plan 010: Fix cheatsheet modular zsh scan and nvim vim.pack update

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 5d08aa5..HEAD -- bin/cheatsheet bin/update-everything nvim/`

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (assumes modular `zsh/` from plan 002)
- **Category**: dx
- **Planned at**: commit `5d08aa5`, 2026-08-08

## Why this matters

After modularizing `.zshrc`, `bin/cheatsheet` only greps the thin orchestrator
and finds almost no aliases/functions. `bin/update-everything` still runs
`nvim --headless "+Lazy! sync"` though Neovim uses **vim.pack**, not LazyVim —
daily updates silently fail or no-op.

## Current state

```bash
# bin/cheatsheet — only .zshrc
parse_zsh_aliases() {
    local zshrc="$DOTFILES_DIR/.zshrc"
    grep -E "^alias [^-]" "$zshrc" ...
}

# bin/update-everything
if nvim --headless "+Lazy! sync" +qa 2>/dev/null; then
```

Live layout: aliases in `zsh/aliases.zsh`, `zsh/git.zsh`; fzf helpers in
`zsh/tools/fzf.zsh`; plugins via `vim.pack.add` in `nvim/init.lua`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Check | `make check` | exit 0 |
| Cheatsheet | `bin/cheatsheet -l 2>/dev/null \| head -30` | shows zsh aliases like `gs`, `ll` |
| Nvim update dry | `rg -n 'Lazy' bin/update-everything` | no Lazy plugin manager refs (LazyGit OK if any) |

## Scope

**In scope**:
- `bin/cheatsheet`
- `bin/update-everything` (nvim plugin update function + dry-run messages only)

**Out of scope**:
- Rewriting all of update-everything
- Changing nvim plugin set
- Starship / prompt work

## Git workflow

- Branch: `advisor/010-cheatsheet-nvim-update`
- Commit: `fix: scan zsh modules in cheatsheet; update nvim via vim.pack`
- Do NOT push/PR unless asked

## Steps

### Step 1: Cheatsheet scans `zsh/**/*.zsh`

1. Collect files: `"$DOTFILES_DIR/.zshrc"` plus `"$DOTFILES_DIR"/zsh/**/*.zsh` (use `find` or zsh/bash glob; portable `find` preferred in bash script).
2. `parse_zsh_aliases`, `parse_zsh_functions`, `parse_zsh_fzf` iterate those files (or a shared `zsh_config_files` helper).
3. Update header comment: “Parses .zshrc, zsh/**/*.zsh, .tmux.conf, .gitconfig”.
4. Function label can say `defined in zsh/` instead of only `.zshrc`.

**Verify**:

```bash
bin/cheatsheet -l 2>/dev/null | grep -E '\[zsh-alias\].*\bgs\b|\[zsh-alias\].*\bll\b' | head
# expect at least gs and ll
```

### Step 2: Nvim update for vim.pack

Replace Lazy sync with a vim.pack-friendly headless update. Prefer:

```bash
nvim --headless "+lua vim.pack.update()" +qa
```

If that API is uncertain on the installed Neovim version, use a documented
fallback that still does not call Lazy:

```bash
# Prefer vim.pack; fail clearly if unavailable
nvim --headless "+lua pcall(vim.cmd, 'packupdate')" +qa
```

Check current Neovim docs at execution time (`:help vim.pack` or
`nvim --headless "+lua print(vim.inspect(vim.pack))"`). **Do not leave Lazy! sync.**

Also update the dry-run echo string that still prints `+Lazy! sync`.

**Verify**: `rg -n 'Lazy!' bin/update-everything` → no matches.
`bash -n bin/update-everything`.

### Step 3: make check

```bash
make check
```

## Done criteria

- [ ] cheatsheet lists aliases from `zsh/` modules
- [ ] update-everything does not invoke Lazy
- [ ] `make check` exit 0
- [ ] `plans/README.md` 010 → DONE

## STOP conditions

- vim.pack has no stable update API on the operator’s nvim — skip auto-update and print info to update plugins manually; do not reintroduce Lazy
- cheatsheet performance tanks scanning huge trees — only scan `zsh/` and `.zshrc`, never `oh-my-zsh/`

## Maintenance notes

- New zsh modules under `zsh/` are auto-included via find
- Reviewers: confirm nvim headless command on CI/ubuntu if available
