# Plan 006: Add a `dot` CLI dispatcher for `bin/`

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat a52b4b5..HEAD -- bin/ Makefile install.sh README.md bin/README.md`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `a52b4b5`, 2026-08-07

## Why this matters

`bin/` has many useful tools (`doctor`, `brew-sync`, `update-everything`,
`good-morning`, …) but discovery is weak unless you read `bin/README.md`. A
single `dot` entrypoint (`dot doctor`, `dot brew-sync`, `dot help`) matches
modern CLI UX and gives a place for shared flags later without renaming every
script.

## Current state

- `PERSONAL_BIN="$DOTFILES_DIR/bin"` on PATH via `.zshrc` `path_add`
- Scripts are standalone executables; some use `bin/lib/helpers.sh`
- `bin/README.md` documents a subset
- No top-level `dot` command

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Check | `make check` | exit 0 |
| Shellcheck | `shellcheck bin/dot` (once added to Makefile list) | exit 0 |
| Help | `dot help` or `bin/dot help` | lists subcommands |
| Dispatch | `dot doctor --skip-tools` | same as `doctor --skip-tools` |

## Scope

**In scope**:
- New `bin/dot` dispatcher script
- `Makefile` `SHELLCHECK_FILES` include `bin/dot`
- `bin/README.md` + root `README.md` short mention
- Optional: `bin/lib/helpers.sh` only if shared arg parsing is tiny and reused
- Optional thin zsh alias `alias dot=...` unnecessary if `bin` on PATH

**Out of scope**:
- Rewriting all bin scripts into subcommands of one file
- Removing direct `doctor` / `brew-sync` executables (keep both: direct and via `dot`)
- Ruby/Python rewrites

## Git workflow

- Branch: `advisor/006-dot-cli`
- Commit: `feat: add dot CLI dispatcher`
- Do NOT push/PR unless asked

## Steps

### Step 1: Design subcommand map

Map:

| Subcommand | Invokes |
|------------|---------|
| `help` / `--help` / no args | print help |
| `doctor` | `bin/doctor` |
| `brew-sync` | `bin/brew-sync` |
| `update` | `bin/update-everything` |
| `good-morning` | `bin/good-morning` |
| `cheatsheet` | `bin/cheatsheet` |
| … | auto-discover other executables in `bin/` that are not `dot` itself and not under `lib/` |

**Policy**:

- Prefer **explicit** allowlist for first-class commands with descriptions
- Plus **auto-list** any other executable files in `bin/` (not directories, not `lib/`, not `*.py` unless intentional) as secondary commands

### Step 2: Implement `bin/dot`

Requirements:

- `#!/usr/bin/env bash` and `set -euo pipefail`
- Resolve `DOTFILES_BIN` from script location
- `dot <cmd> [args...]` → `exec "$DOTFILES_BIN/<cmd>" "$@"` after validating cmd is safe:
  - no path separators in `<cmd>`
  - target is executable regular file inside `DOTFILES_BIN`
  - reject `lib` and hidden names
- `dot help` prints formatted list (name + first `#` description line or static map)
- Unknown command → stderr message + exit 1
- Pass through exit codes from subcommands

Exemplar patterns: see `bin/doctor` for helpers usage; keep `dot` dependency-light.

**Verify**:

```bash
chmod +x bin/dot
bin/dot help | head -40
bin/dot doctor --skip-tools
bin/dot nosuchcommand; test $? -ne 0
```

### Step 3: ShellCheck + Makefile

Add `bin/dot` to `SHELLCHECK_FILES` in `Makefile`.

**Verify**: `make shellcheck` exit 0.

### Step 4: Documentation

- `bin/README.md`: top section “Use `dot help` to discover commands”
- Root README: one line under features or scripts

**Verify**: `rg -n '\\bdot\\b' README.md bin/README.md`.

### Step 5: Optional completion (stretch)

If easy, add zsh completion file under a completions path already on fpath —
**skip** if it requires large machinery. Not required for done criteria.

## Test plan

- `bin/dot help` lists doctor
- `bin/dot doctor --skip-tools` works
- `bin/dot brew-sync --help` or dry-run if available
- Path traversal rejected: `bin/dot ../.zshrc` must fail
- `make check` passes

## Done criteria

- [ ] `bin/dot` exists, executable, dispatches safely
- [ ] `dot help` discovers primary tools
- [ ] Existing scripts still runnable directly
- [ ] Makefile shellcheck includes `bin/dot`
- [ ] Docs mention `dot`
- [ ] `make check` exit 0
- [ ] `plans/README.md` 006 → DONE

## STOP conditions

- Dispatch design would require rewriting `update-everything` interfaces
- Security issue: cannot reliably prevent path escape — stop and simplify to
  strict allowlist only

## Maintenance notes

- New bin scripts: add to allowlist descriptions when important; auto-discover covers the rest
- Reviewers: focus on path safety in dispatcher
- Follow-up: `dot install` wrapping `install.sh` flags
