# Plan 003: 1Password-native secrets loading

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat a52b4b5..HEAD -- api_keys.sh.template api_keys_1password.sh.template .zshrc install.sh bin/doctor README.md CLAUDE.md`
> Never print or commit real secret values. Reference paths and variable **names** only.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (auth UX / missing `op` session)
- **Depends on**: none (independent of 001/002; if 002 landed, edit `zsh/secrets.zsh` instead of `.zshrc`)
- **Category**: security
- **Planned at**: commit `a52b4b5`, 2026-08-07

## Why this matters

Secrets are loaded by sourcing `api_keys.sh` (plain exports) and optionally
`api_keys_1password.sh`. The 1Password template exists but is example-only; the
install path still pushes people toward a plaintext `api_keys.sh`. Long-lived
API keys in every interactive shell increase exposure (shell history, process
environments, accidental `env` dumps, backups).

This plan makes **1Password the preferred path**, keeps a narrow plaintext
escape hatch for bootstrap/non-1P machines, avoids putting secret values in the
repo, and documents `op` session requirements.

## Current state

```zsh
# .zshrc (~335–339)
[ -f "$DOTFILES_DIR/api_keys.sh" ] && source "$DOTFILES_DIR/api_keys.sh"
[ -f "$DOTFILES_DIR/api_keys_1password.sh" ] && source "$DOTFILES_DIR/api_keys_1password.sh"
```

```gitignore
api_keys.sh
api_keys_1password.sh
```

- `api_keys.sh.template` — sample `LANGCHAIN_*`, `OPENAI_API_KEY`, `TAVILY_API_KEY`
- `api_keys_1password.sh.template` — defines `op_secret` helper + commented examples
- `Brewfile` — `cask "1password-cli"`
- `install.sh` — `install_api_keys_template` copies **only** `api_keys.sh.template` → `api_keys.sh`

**Security rules for this plan**: never write real keys into templates, commits,
plan files, or command output. If you encounter a live `api_keys.sh` while
testing, do not `cat` it into logs.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Lint | `make check` | exit 0 |
| op present | `command -v op` | path to op |
| op auth (operator) | `op whoami` | signed-in account; if fails, document offline mode |
| Zsh parse | `zsh -n` on touched shell files | exit 0 |
| Doctor | `bin/doctor` | warns if no secrets file; does not fail closed on missing op |

## Scope

**In scope**:
- `api_keys_1password.sh.template` (primary)
- `api_keys.sh.template` (clarify bootstrap-only)
- `.zshrc` **or** `zsh/secrets.zsh` if plan 002 merged
- `install.sh` api-keys install flow
- `bin/doctor` secrets checks (presence + optional `op` health)
- `README.md` / `CLAUDE.md` short secrets section
- Optional: `docs/secrets.md` **only if** README would become too long (prefer one new doc)

**Out of scope**:
- Storing or rotating the operator’s real vault items
- AWS credential process deep integration (may mention `op` plugin as optional)
- Changing mcp.json tokens
- Committing `api_keys.sh` or `api_keys_1password.sh`

## Git workflow

- Branch: `advisor/003-1password-secrets`
- Commit style: `feat: prefer 1Password for API keys`, `docs: secrets loading`
- Do NOT push/PR unless asked

## Steps

### Step 1: Drift check + confirm templates

```bash
test -f api_keys.sh.template && test -f api_keys_1password.sh.template
# Ensure real secret files are gitignored
git check-ignore -v api_keys.sh api_keys_1password.sh
```

**Verify**: both templates tracked; both live files ignored.

### Step 2: Harden `api_keys_1password.sh.template`

Rewrite the template to be **ready to copy** with safer defaults:

1. Keep `op_secret` but make it:
   - no-op with empty output if `op` missing or not signed in
   - optional one-time stderr warning (rate-limited or only if `DOTFILES_DEBUG=1`)
2. Prefer documenting **`op://Vault/Item/field`** refs clearly.
3. Add a header comment: “Copy to `api_keys_1password.sh` (gitignored). Prefer this over `api_keys.sh`.”
4. Add optional pattern for lazy export if appropriate — **only if simple**:

```bash
# Example pattern (illustrative — put real item paths in the gitignored copy only):
# export OPENAI_API_KEY=$(op_secret "Private/OpenAI/credential")
```

5. Document alternative: `op run --env-file=... -- <command>` for one-shot commands
   without exporting into the parent shell (comment block is enough).

6. **Do not** add real vault paths that look like production secrets from the operator’s machine into the tracked template beyond the existing Private/Service examples.

**Verify**: `bash -n api_keys_1password.sh.template` or `zsh -n` as appropriate; file contains `op_secret` and no long random-looking tokens.

### Step 3: Demote `api_keys.sh.template`

Update header to say:

- Bootstrap / machines without 1Password only
- Prefer `api_keys_1password.sh`
- Never commit the real file

Keep placeholder variable names; empty values OK.

**Verify**: first 15 lines mention bootstrap / 1Password preference.

### Step 4: Install flow prefers 1Password template

In `install.sh` `install_api_keys_template` (or successor):

1. If neither live file exists, offer:
   - **Preferred**: copy `api_keys_1password.sh.template` → `api_keys_1password.sh`
   - **Fallback**: copy `api_keys.sh.template` → `api_keys.sh`
2. In `--yes` headless mode: create **1Password** stub by default (not plaintext), unless `--skip-api-keys`.
3. Print next steps: enable 1Password CLI integration; run `op signin`; edit refs.

**Verify**:

```bash
./install.sh --plan --skip-brew --skip-oh-my-zsh 2>&1 | rg -i 'api.key|1password|op' || true
# Plan mode should mention 1Password path
```

(Adjust `--skip-oh-my-zsh` if plan 002 removed the flag.)

### Step 5: Shell load order and safety

In `.zshrc` or `zsh/secrets.zsh`:

```zsh
# Secrets: 1Password-backed file preferred; plaintext bootstrap optional.
# Plaintext may override if sourced second — prefer only one file active.
[ -f "$DOTFILES_DIR/api_keys.sh" ] && source "$DOTFILES_DIR/api_keys.sh"
[ -f "$DOTFILES_DIR/api_keys_1password.sh" ] && source "$DOTFILES_DIR/api_keys_1password.sh"
```

Document that **1Password file is sourced second** so it can override plaintext
during migration. Add comment that long-term users should delete plaintext keys
from `api_keys.sh`.

Optional improvement (nice-to-have, not required): if both exist and
`DOTFILES_DEBUG=1`, print which files were sourced (names only).

**Verify**: `zsh -n` on the file; `rg -n 'api_keys' .zshrc zsh/secrets.zsh 2>/dev/null`.

### Step 6: Doctor checks

Extend `bin/doctor`:

1. Keep warning if **neither** secrets file exists.
2. If `api_keys_1password.sh` exists:
   - `command -v op` → warning if missing
   - `op whoami` → warning if not signed in (do not fail entire doctor by default)
3. If only `api_keys.sh` exists → info/warning: “prefer 1Password-backed secrets”
4. **Never** read or print file contents

**Verify**: `bin/doctor --skip-tools` still runs; with no op session, warnings only.

### Step 7: Docs

Add a short “Secrets” subsection to `README.md` (and one paragraph in `CLAUDE.md`):

- 1Password CLI + app integration
- copy template → gitignored file
- `op whoami` / Desktop app unlock
- plaintext template is bootstrap-only
- reminder: no secrets in git

**Verify**: `rg -n '1Password|api_keys' README.md CLAUDE.md`.

## Test plan

- Templates parse; install plan mode mentions 1P
- Doctor warning paths (simulate by renaming files only in a temp HOME if easy;
  otherwise manual)
- **Operator** (not executor) validates `op read` for one dummy item
- `make check` passes
- `git status` does not show `api_keys.sh` with secrets staged

## Done criteria

- [ ] 1Password template is the documented preferred path
- [ ] install.sh default/prefer creates `api_keys_1password.sh` from template
- [ ] Shell still sources both files with documented order
- [ ] doctor checks op presence/session without leaking secrets
- [ ] README/CLAUDE document the flow
- [ ] No real secrets in any tracked file (`git grep` for high-entropy strings if unsure — do not add secrets)
- [ ] `make check` exit 0
- [ ] `plans/README.md` 003 → DONE

## STOP conditions

- Live `api_keys.sh` is accidentally staged — unstage immediately; never commit
- `op` integration requires policy changes the operator must approve interactively
  beyond template docs
- Conflicting secret loaders appear in `mac_specific.sh` / gitignored org files
  that redefine the same vars in unsafe ways — report, don’t rewrite org files

## Maintenance notes

- New API keys: add vault item + one line in **gitignored** `api_keys_1password.sh`
- Reviewers: ensure templates stay placeholder-only
- Follow-up: shell plugins for gh/aws; `direnv` + `op inject` per project (plan 005)
- If plan 007 agents need keys, point them at the same 1P-backed env, not new plaintext files
