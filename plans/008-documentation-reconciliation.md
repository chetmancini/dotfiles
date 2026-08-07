# Plan 008: Documentation reconciliation pass

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat a52b4b5..HEAD -- README.md CLAUDE.md docs/ bin/README.md`
> Then reconcile docs against **live** tree, not against this plan’s older excerpts.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: best after 001–007; can run partial updates anytime
- **Category**: docs
- **Planned at**: commit `a52b4b5`, 2026-08-07

## Why this matters

Docs already drift from reality: **LazyVim** is documented while `nvim/init.lua`
uses **`vim.pack`**; README still mentions oh-my-zsh/pyenv/`n` depending on
which plans landed. Agent executors and future-you will reintroduce the wrong
stack if docs stay stale.

## Current state (as of a52b4b5 — re-verify)

Known falsehoods at plan time:

| Doc claim | Reality |
|-----------|---------|
| Neovim is LazyVim / lazy.nvim | `nvim/init.lua` uses `vim.pack.add({...})` + `plugin/*.lua` |
| zsh uses oh-my-zsh heavily | Minimal OMZ plugin use; theme custom (002 removes OMZ) |
| pyenv + nvm / `n` primary | mise present; 001 consolidates |
| `docs/neovim.md` tree shows `lua/config/lazy.lua` | Tree is `init.lua` + `plugin/*.lua` |

Files to audit:

- `README.md`
- `CLAUDE.md` (and `Claude.md` if duplicate path — use actual filename in repo)
- `docs/README.md`, `docs/neovim.md`, `docs/tmux.md`, `docs/yazi.md`, `docs/ghostty.md`, `docs/bin.md`
- `bin/README.md`
- `bin/lib/symlinks.sh` description strings (user-visible in install UI)

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Find stale terms | `rg -n 'LazyVim|lazy\\.nvim|oh-my-zsh|pyenv|nvm|\\bn\\b' README.md CLAUDE.md docs/ bin/README.md` | only intentional historical mentions |
| Tree sample | `find nvim -type f | head -40` | matches neovim docs |
| Check | `make check` | exit 0 (docs-only usually no-op) |

## Scope

**In scope**:
- All markdown docs listed above
- Symlink description strings in `bin/lib/symlinks.sh` if they say LazyVim
- Optional: short architecture diagram in README reflecting `zsh/` modules if 002 done

**Out of scope**:
- Code behavior changes
- Rewriting every bin script’s header comments
- External blog posts

## Git workflow

- Branch: `advisor/008-docs-reconciliation`
- Commit: `docs: reconcile README and neovim docs with vim.pack stack`
- Do NOT push/PR unless asked

## Steps

### Step 1: Inventory live architecture

```bash
# Editor
ls nvim/; head -30 nvim/init.lua
# Shell
ls zsh 2>/dev/null || echo 'no zsh/ modules yet'
# Brew profiles
ls Brewfile* 
# Secrets templates
ls api_keys*.template
```

Build a checklist of “source of truth” facts from the tree.

### Step 2: Fix neovim docs

Rewrite `docs/neovim.md` to describe:

- `vim.pack` plugin management
- `nvim/plugin/*.lua` modules (completion, lsp, git, …)
- Catppuccin, blink.cmp, mason, conform, etc. **as actually listed** in `init.lua`
- Remove LazyVim keybind links as primary; document local leader and keymaps from `init.lua` / plugin files
- Update `docs/README.md` neovim one-liner

**Verify**: `rg -n 'LazyVim|lazy\\.nvim' docs/neovim.md` → no matches (unless a “Migration from LazyVim” note).

### Step 3: Fix root README + CLAUDE.md

Align sections:

- What’s included table
- Shell features (modules / mise / atuin if present)
- Languages: mise + uv + pnpm/bun
- Tree diagram (`oh-my-zsh/` only if still relevant)
- Bootstrap/doctor still accurate

**Verify**: stale term `rg` from commands table is clean or justified.

### Step 4: Symlink description strings

```bash
rg -n 'LazyVim|oh-my-zsh' bin/lib/symlinks.sh || echo clean
```

Update Neovim description to “Neovim config (vim.pack + modular plugin/*.lua)”.

### Step 5: Cross-links to plans (optional)

In `docs/README.md` or root README, optional one-liner: “Modernization plans live in `plans/`” — only if you want discoverability; not required.

### Step 6: Final grep gate

```bash
rg -n 'LazyVim|lazy\\.nvim' README.md CLAUDE.md docs/ bin/ || true
rg -n 'oh-my-zsh' README.md CLAUDE.md docs/ || true
```

Any remaining hits must be intentional (e.g. “removed in 2026”).

**Verify**: `make check` still passes.

## Test plan

- Human read of README quick start still works
- `docs/neovim.md` file tree matches `find nvim`
- No broken relative links in docs (`rg '\\]\\(\\.\\./|\\]\\(\\./' docs/`)

## Done criteria

- [ ] No inaccurate LazyVim claims
- [ ] Shell/version-manager docs match post-001/002 reality (as landed)
- [ ] Symlink install descriptions accurate
- [ ] `make check` exit 0
- [ ] `plans/README.md` 008 → DONE

## STOP conditions

- Mid-migration tree (half 002) makes one coherent doc story impossible — write
  docs for **current HEAD** and note TODOs rather than inventing end state
- Conflicting CLAUDE.md vs Claude.md files — report duplication; don’t delete
  without confirmation

## Maintenance notes

- Any future stack change should update `docs/neovim.md` in the same PR
- Reviewers: compare docs tree blocks to `ls`
- This plan should be re-run after large modernization merges
