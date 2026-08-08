# Plan 013: `dot install` wrapper and install/doctor characterization (deferred)

> **Executor instructions**: Do not start until operator prioritizes this plan.
>
> **Drift check**: `git diff --stat 5d08aa5..HEAD -- bin/dot install.sh bin/doctor .github/workflows/smoke.yml`

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW
- **Depends on**: 006 done; 009 recommended (green doctor)
- **Category**: direction
- **Planned at**: commit `5d08aa5`, 2026-08-08
- **Status note**: Implemented — `dot install` + `scripts/test-install-smoke.sh` / `make install-smoke`

## Why this matters

`dot` dispatches tools but not `install.sh`. CI has install smoke; local doctor
was noisy (009). A thin `dot install [--plan|--yes|…]` and a few characterization
tests lock bootstrap behavior as flags grow.

## Scope

**In scope**: `bin/dot` (map `install` → `../install.sh` or `$DOTFILES_DIR/install.sh`), optional `scripts/test-install-smoke.sh`, CI wire-up  
**Out of scope**: Rewriting install.sh UI; plan 007 agents

## Steps (summary)

1. Resolve repo root from `bin/dot`; `dot install` execs `install.sh` with remaining args.
2. Document in `bin/README.md` and `dot help` primary list.
3. Optional: shell test script that runs `install.sh --plan --yes --skip-brew` in temp HOME (mirror CI).
4. `make check`; manual `dot install --help` / `--plan`.

## Done criteria

- [ ] `dot install --help` or plan mode works
- [ ] `make check` exit 0
- [ ] `plans/README.md` 013 → DONE

## STOP

- install.sh path resolution breaks when bin is symlinked — fix root detection like other bin scripts
