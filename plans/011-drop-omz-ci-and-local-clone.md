# Plan 011: Drop oh-my-zsh from CI fixtures and local leftover clone

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 5d08aa5..HEAD -- .github/workflows/smoke.yml .gitignore README.md CLAUDE.md install.sh`

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plan 002 done (no runtime OMZ)
- **Category**: tech-debt
- **Planned at**: commit `5d08aa5`, 2026-08-08

## Why this matters

OMZ is no longer used at runtime (plan 002). CI still creates
`oh-my-zsh/custom/themes` as a bootstrap fixture; local clones may still sit
in `~/dotfiles/oh-my-zsh` (gitignored). That confuses greps, `make` file
discovery history, and onboarding (“is OMZ required?”).

## Current state

```yaml
# .github/workflows/smoke.yml
- name: Prepare bootstrap fixtures
  run: |
    mkdir -p "$GITHUB_WORKSPACE/oh-my-zsh/custom/themes"
```

`.gitignore` still has `oh-my-zsh` (keep so old clones aren’t committed).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Check | `make check` | exit 0 |
| CI local | n/a (push will run) | install-smoke no longer needs OMZ dir |

## Scope

**In scope**:
- `.github/workflows/smoke.yml` — remove OMZ mkdir fixture
- Optional one-line note in README or CLAUDE if still mentioning leftover clone cleanup
- **Optional operator step** (document only): `rm -rf ~/dotfiles/oh-my-zsh` after confirming shell works — executor may run this **only if** the path is gitignored and is not tracked (`git ls-files oh-my-zsh` empty)

**Out of scope**:
- Deleting tracked `vim/` or `iterm/` (operator opt-in elsewhere)
- Reintroducing OMZ

## Git workflow

- Branch: `advisor/011-drop-omz-ci`
- Commit: `chore: remove oh-my-zsh from CI smoke fixtures`
- Do NOT push/PR unless asked

## Steps

### Step 1: CI fixture

Remove the `mkdir -p ... oh-my-zsh/custom/themes` line from smoke.yml. Keep
other fixture dirs (`$RUNNER_TEMP/home`, etc.).

**Verify**: `rg -n 'oh-my-zsh' .github/` → no matches (or only a comment).

### Step 2: Local clone (optional)

```bash
git ls-files oh-my-zsh | head
# must be empty
# If directory exists and is untracked:
# rm -rf oh-my-zsh   # only if operator wants; plan allows it for streamlining
```

Keep `.gitignore` entries for `oh-my-zsh`.

**Verify**: `test ! -d oh-my-zsh` if deleted; shell still works: `zsh -n .zshrc`.

### Step 3: Docs touch (minimal)

If CLAUDE/README still say “optional cleanup remove oh-my-zsh”, keep or note
“safe to delete; unused since plan 002”.

## Done criteria

- [ ] CI smoke does not create oh-my-zsh
- [ ] `.gitignore` still ignores oh-my-zsh
- [ ] `make check` exit 0
- [ ] `plans/README.md` 011 → DONE

## STOP conditions

- CI install-smoke fails for a reason that actually required OMZ — investigate install.sh for residual OMZ paths (should be none after 002)
- `oh-my-zsh` is tracked in git unexpectedly — do not `rm -rf`; report

## Maintenance notes

- vim/iterm cleanup remains separate operator decision
