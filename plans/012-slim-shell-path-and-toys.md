# Plan 012: Slim shell PATH product bins and optional toys (deferred)

> **Executor instructions**: Do not start until operator prioritizes this plan.
> When executing, follow steps and update `plans/README.md`.
>
> **Drift check**: `git diff --stat 5d08aa5..HEAD -- zsh/path.zsh zsh/fun.zsh zsh/functions.zsh Brewfile.optional`

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW–MED (PATH removals can hide tools)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `5d08aa5`, 2026-08-08

## Why this matters

`zsh/path.zsh` prepends many product-specific bins (LM Studio, Antigravity,
Browser Use, Grok, Turso, …). Existence-checked, but the list grows without
review. `thefuck` and `cmatrix` screensaver are optional-weight toys.

## Current state

See `zsh/path.zsh` path_add list; `zsh/fun.zsh` TMOUT/cmatrix; `zsh/functions.zsh` thefuck lazy load.

## Scope

**In scope**: `zsh/path.zsh`, optionally `zsh/fun.zsh` / `zsh/functions.zsh`, comments in Brewfile.optional  
**Out of scope**: Removing core brew CLI tools; mise/direnv/atuin

## Steps (summary)

1. Inventory which path_add entries still exist on disk for the operator.
2. Keep brew, personal bin, uv, pnpm, bun, java, grok if used weekly; comment or move rare product paths behind a small `path.extra.zsh` gitignored or optional module.
3. Optionally drop thefuck if CORRECT + atuin suffice; keep cmatrix only if formula installed.
4. `zsh -n` + interactive PATH smoke.

## Done criteria

- [ ] PATH list documented or reduced with operator agreement
- [ ] `make check` exit 0
- [ ] `plans/README.md` 012 → DONE

## STOP

- Operator still needs a bin daily that was removed — restore it
