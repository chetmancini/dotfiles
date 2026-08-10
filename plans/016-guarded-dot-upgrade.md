# Plan 016: Add a preview-first, fast-forward-only `dot upgrade`

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 2d61df6..HEAD -- bin/upgrade bin/status bin/restore bin/dot install.sh tests/upgrade.bats tests/dot.bats Makefile README.md bin/README.md docs/bin.md plans/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts and the dependency contracts below against the live
> code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plan 014 (`dot status`) and plan 015 (install transactions / `dot restore`)
- **Category**: direction
- **Planned at**: commit `2d61df6`, 2026-08-10

## Why this matters

The repository exposes install, update, and doctor commands but has no guarded
workflow for moving an installed dotfiles checkout to a newer declared state.
The generated good-morning configuration even advertises dotfiles-update keys
that the updater never consumes. A preview-first `dot upgrade` should fetch and
explain a fast-forward, show the future install plan, require explicit apply,
retain recovery pointers, and verify the resulting machine without ever
resetting a dirty or diverged checkout.

## Current state

- `bin/dot` advertises `install`, `doctor`, and `update` as separate lifecycle
  commands.
- `bin/good-morning` generates `PULL_DOTFILES` and `DOTFILES_DIR` settings, but
  `bin/update-everything` does not initialize or use either key.
- `bin/update-everything` performs Homebrew/npm/Docker/Neovim/repository
  maintenance; it is not a safe place to silently self-modify the dotfiles
  checkout.
- `install.sh --plan` can preview symlink actions without changing HOME.
- The current branch is expected to track the remote default branch, but this
  repository is also used in Conductor workspaces and feature branches. Upgrade
  must refuse those non-default/dirty/diverged contexts rather than treating
  them as the live installed checkout.

Current excerpts:

```bash
# bin/dot:27-35
install) echo "Run install.sh (bootstrap / re-link; pass flags through)" ;;
doctor) echo "Verify dotfiles installation health" ;;
brew-sync) echo "Check and sync Brewfile with installed packages" ;;
update | update-everything) echo "Run system/package update routine" ;;
good-morning) echo "Run a configurable set of tasks to start the day" ;;
cheatsheet) echo "Quick reference for aliases, keybindings, and functions" ;;
dashboard) echo "Show useful information at a glance" ;;
```

```bash
# bin/good-morning:117-119 (generated config text)
# Dotfiles updates
# PULL_DOTFILES=true
# DOTFILES_DIR="$HOME/dotfiles"
```

```bash
# bin/update-everything:23-35
CONFIG_DIR="$HOME/.config/good-morning"
CONFIG_FILE="$CONFIG_DIR/config"

DEFAULT_REPOS_DIRS=("$HOME/code" "$HOME/norm")
DEFAULT_RUN_BREW_UPDATE=true
DEFAULT_RUN_BREW_UPGRADE=true
DEFAULT_RUN_BREW_CLEANUP=true
DEFAULT_RUN_NPM_GLOBAL_UPDATE=true
DEFAULT_PULL_REPOS=true
DEFAULT_DOCKER_PRUNE=true
DEFAULT_CHECK_MACOS_UPDATES=true
DEFAULT_UPDATE_NVIM_PLUGINS=true
```

This plan depends on two public contracts. Verify them from the live code before
starting; do not infer or reimplement them:

1. **Status contract from plan 014**
   - `bin/status` exists and `dot status --json` emits schema
     `dotfiles.status/v1`.
   - Exit `0` means healthy, `1` means warnings/drift, `2` means hard failure,
     and `64` means usage error.
2. **Restore contract from plan 015**
   - A changed install records `~/.dotfiles-backup/latest` as a validated plain
     transaction ID.
   - `dot restore --plan <ID>` previews recovery; `dot restore --apply <ID>` is
     the only component that restores managed HOME targets.

The upgrade command's own state lives separately:

```text
~/.dotfiles-upgrades/<upgrade-id>/metadata
```

Required metadata keys are `version=1`, `id`, `created_at`, `state`, `remote`,
`branch`, `before_sha`, `target_sha`, and, after apply, `after_sha` and
`install_transaction_id`. Allowed states are `applying`, `complete`, and
`failed`. Parse it as allowlisted data; never source it.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Focused upgrade tests | `bats tests/upgrade.bats tests/dot.bats` | all tests pass using local disposable Git remotes |
| Shell syntax | `bash -n bin/upgrade bin/dot install.sh` | exit `0` |
| ShellCheck | `shellcheck --severity=warning -x -P bin bin/upgrade bin/dot install.sh` | exit `0` |
| Full repository gate | `make check` | exit `0`; all Bats tests pass |

## Scope

**In scope** (the only files the executor may modify):

- `bin/upgrade` — create the guarded lifecycle command.
- `bin/dot` — promote `upgrade` to the primary command list.
- `install.sh` — add only the preview-only managed-source-root contract needed
  to preview a target revision before checkout.
- `tests/upgrade.bats` — create isolated remote/checkout/recovery coverage.
- `tests/dot.bats` — assert upgrade discovery/help dispatch.
- `Makefile` — add `bin/upgrade` to explicit ShellCheck inputs.
- `README.md`, `bin/README.md`, `docs/bin.md` — document preview/apply,
  preconditions, safe defaults, and recovery output.
- `plans/README.md` — update this plan's status when complete.

`bin/status` and `bin/restore` are dependency inputs and are listed in the drift
check, but are **read-only for this plan**. `install.sh` may change only to add
the preview-only `--managed-root PATH` contract described in step 2; do not
alter its apply behavior.

**Out of scope** (do not touch):

- `bin/update-everything` or `bin/good-morning`. Remove/document their stale
  generated keys only in a separate cleanup after upgrade is proven.
- Git rebase, merge commits, force/reset operations, auto-stashing, branch
  switching, detached-HEAD repair, or local commit publication.
- Homebrew/package upgrades, API-key setup or validation, tmux installation,
  Git hook replacement, macOS defaults, or machine-profile selection.
- Automatic rollback. On failure, print recovery references and stop; do not
  reset Git or invoke restore automatically.
- Scheduled/unattended upgrades or background launch agents.
- Supporting arbitrary remotes/branches in v1; use `origin` and its detected
  default branch only.

## Git workflow

- Branch: `advisor/016-guarded-dot-upgrade`
- Use a conventional commit such as `feat(dot): add guarded self-upgrade`.
- Keep `bin/upgrade` executable.
- Do not push or open a PR unless the operator asks.

## Steps

### Step 1: Implement strict repository preflight

Create executable `bin/upgrade` using the symlink-safe script/root resolution
pattern from `bin/dot`. Its CLI is exactly:

```text
dot upgrade                 # same as --plan
dot upgrade --plan
dot upgrade --apply [--yes]
dot upgrade --help
```

Unknown/incompatible flags exit `64`. `--apply` is the only working-tree apply
mode; `--yes` is valid only with `--apply`.

Before any fetch, require all of the following:

1. The resolved dotfiles directory is a Git working tree.
2. Remote `origin` exists.
3. The working tree and index are clean, including untracked files
   (`git status --porcelain` is empty).
4. HEAD is attached.
5. `refs/remotes/origin/HEAD` resolves to a default branch. If it is absent,
   allow only the existing remote branch `origin/main` or `origin/master`, in
   that order; refuse ambiguity when both exist and remote HEAD is unset.
6. The current local branch name exactly equals the detected default branch.

Then run `git fetch --prune origin`. Fetching remote refs is the only mutation
allowed in plan mode; document this in help/output. Recheck cleanliness after
fetch and compute:

```bash
git rev-list --left-right --count HEAD...origin/<default>
```

- `0 0`: already current; exit `0` with no install or status run.
- `0 N`: fast-forward candidate; continue.
- Any local-ahead count or divergence: exit `2` and print instructions to resolve
  manually. Never merge, rebase, switch, stash, or reset.

Use exit `0` for a successful plan/no-op, `1` only when post-apply status has
warnings, `2` for hard preflight/apply/verification failure, and `64` for usage.

**Verify**: `bats tests/upgrade.bats` → tests cover non-repo, missing origin,
dirty/untracked, detached, non-default, ambiguous default, current, behind,
ahead, and diverged cases using only disposable local remotes.

### Step 2: Preview the target revision without checking it out

First add one narrow installer contract. `install.sh` accepts
`--managed-root ABSOLUTE_PATH` only together with `--plan`:

- The installer code and `bin/lib/symlinks.sh` continue loading from its own
  `SCRIPT_DIR` (the archived target revision).
- Managed symlink source paths are displayed as if the repository lived at the
  supplied absolute root (the live checkout path after fast-forward).
- Package, secrets, TPM, and hook code must reject or never consume the override;
  upgrade always skips those surfaces.
- Reject relative paths, missing roots, control characters, and use without
  `--plan` with exit `64`.
- With no override, preserve every existing installer behavior and path.

This avoids a false preview where every managed link appears to point at a
temporary archive that will be deleted.

Then, for a fast-forward candidate, plan mode must:

- Print current SHA, target SHA, detected branch, commit list
  (`git log --oneline HEAD..origin/<default>`), and diff stat.
- Create an explicit `mktemp -d` directory and export the target tree into it
  with `git archive origin/<default> | tar -x -C <temp>`. Do not use a secondary
  Git worktree and do not modify the current index or working tree.
- Register cleanup immediately and remove only the validated explicit temp
  directory created by this process.
- Confirm the target archive contains executable `install.sh` and supports all
  required safe flags in its help. If its CLI drifted, stop before apply.
- Run the **target revision's** installer against the actual HOME in preview
  mode, representing future links with the live checkout root, using exactly:

```bash
install.sh --plan --managed-root "$DOTFILES_DIR" --yes --skip-brew --skip-api-keys --skip-tpm --skip-hooks --no-clear
```

- Print that package upgrades, secrets, TPM, hooks, and macOS settings are not
  part of v1 upgrade.
- Write no upgrade metadata and no install transaction in plan mode.

Because the target installer runs with `--plan`, it must not modify HOME. If the
target revision cannot demonstrate this established contract, stop.

**Verify**: in `tests/upgrade.bats`, default/`--plan` reports the target commit
and future install actions while HEAD, tracked files, HOME fixtures, and upgrade
state remain unchanged (remote-tracking refs may advance).

### Step 3: Apply only an explicitly confirmed fast-forward

`--apply` repeats the complete preflight and preview rather than trusting stale
state. After preview:

1. Prompt with current and target SHAs unless `--yes`; a negative answer exits
   `0` without metadata or working-tree changes.
2. Allocate an upgrade ID as UTC `YYYYMMDDTHHMMSS-<pid>-<random>` under
   `${DOTFILES_UPGRADE_ROOT:-$HOME/.dotfiles-upgrades}`. Validate the ID and
   refuse collisions.
3. Write version-1 metadata with `state=applying` and the preflight fields. Parse
   this file as data only; never source/eval it.
4. Create a recovery ref pointing to `before_sha`:

```text
refs/dotfiles-upgrades/<upgrade-id>/before
```

5. Reconfirm `git status --porcelain` is empty and the fetched target SHA is
   unchanged, then run `git merge --ff-only origin/<default>`.
6. Run the newly checked-out `install.sh` with the same safe non-package flags,
   but without `--plan`.
7. Read `~/.dotfiles-backup/latest` before and after install. If it changed,
   validate the new complete transaction and record its ID. If it did not
   change, record `install_transaction_id=none`; this relies on plan 015's
   contract that every changed managed target finalizes a new transaction.
   If installer output claims it created/replaced symlinks while `latest` did
   not change, treat that contract mismatch as a hard failure.
8. Run `bin/status --json` from the updated checkout and save its sanitized JSON
   under the upgrade directory as `status-after.json`. Exit `1` but mark the
   upgrade complete if status returns warnings; treat status exit `2+` as failed.
9. Atomically finalize metadata with `after_sha`, transaction ID, and
   `state=complete`.

Do not capture installer/provider raw output in metadata. Console output may be
shown normally, but the upgrade directory contains only allowlisted metadata and
the sanitized `dotfiles.status/v1` document.

**Verify**: `bats tests/upgrade.bats` → apply fast-forwards exactly to target,
creates the recovery ref/metadata, invokes the safe install surface, records the
transaction contract, and stores valid status JSON.

### Step 4: Fail recoverably without automatic rollback

Install an EXIT/error trap only while an apply transaction is active:

- On installer or hard status failure, atomically mark upgrade metadata
  `state=failed` while preserving `before_sha`, `target_sha`, recovery ref, and
  any validated install transaction ID.
- Print exact recovery information:
  - Upgrade ID and metadata path.
  - Recovery ref name and before SHA.
  - `dot restore --plan <transaction-id>` when an install transaction exists.
  - A warning that the checkout remains advanced and Git rollback is a separate
    manual decision.
- Never invoke `git reset`, `git checkout`, `git switch`, `git stash`, or
  `dot restore --apply` from failure handling.
- Preserve the original failure exit `2`; trap/metadata failures must not turn a
  failed upgrade into success.

If failure happens before the working tree advances, still preserve metadata and
the recovery ref for diagnosis.

**Verify**: focused tests simulate installer failure and status hard failure;
both leave an inspectable failed record and recovery ref, do not run restore,
and do not hide the failure exit.

### Step 5: Wire the public command and documentation

- Add `upgrade` to `bin/dot` primary descriptions/order, separate from the
  package-oriented `update` alias.
- Add `bin/upgrade` to `SHELLCHECK_FILES`.
- Document:
  - Default equals preview.
  - Fetch updates remote refs even in preview, but HEAD/HOME remain unchanged.
  - Apply requires a clean checkout on the remote default branch and permits
    only fast-forward.
  - Safe installer flags intentionally exclude packages, credentials, TPM,
    hooks, and macOS preferences.
  - Failure is not automatically rolled back; show where recovery data lives.
- Do not document the stale `PULL_DOTFILES` key as functional. Leave its removal
  to a later narrow cleanup because `good-morning` is out of scope here.

**Verify**: `bats tests/dot.bats tests/upgrade.bats` → dispatcher/help/lifecycle
tests pass.

### Step 6: Run the complete gate and inspect scope

Format only changed shell files, then run the repository gate.

**Verify**:

```bash
shfmt -i 4 -ci -w bin/upgrade bin/dot install.sh tests/upgrade.bats tests/dot.bats
make check
git diff --check
git status --short
```

Expected: every command exits `0`; status lists only files in this plan's
in-scope list plus `plans/README.md` if updated.

## Test plan

Create `tests/upgrade.bats` around a disposable bare `origin`, a disposable
clone, and disposable HOME/upgrade/backup roots. Configure Git identity locally
inside fixtures. Never use the real checkout's remote or network.

Cover at minimum:

1. Help, default-plan equivalence, invalid arguments, and `--yes` without apply.
2. Non-repository and missing-origin failures.
3. Dirty tracked state and untracked files rejected before fetch/apply.
4. Detached HEAD, non-default branch, and ambiguous missing remote HEAD rejected.
5. Already-current checkout exits cleanly without installer/status/metadata.
6. Behind checkout previews commits/diff/future installer without changing HEAD
   or HOME.
7. Ahead and diverged histories refuse without merge/rebase/reset.
8. Target installer missing or lacking required flags refuses before apply;
   installer `--managed-root` is plan-only and preserves normal path behavior.
9. Declined apply makes no metadata/recovery ref/working-tree change.
10. Successful apply fast-forwards, records both SHAs/recovery ref, runs safe
    installer args, captures transaction ID or explicit `none`, and stores valid
    `dotfiles.status/v1` JSON.
11. Post-status warning returns `1` but records `state=complete`.
12. Installer failure and status hard failure return `2`, record `state=failed`,
    print recovery commands, and never auto-reset or restore.
13. Upgrade IDs and metadata are rejected when malformed, colliding, or outside
    the explicit test root.
14. Every test cleans only its own explicit temporary directories.

Fixture target revisions may use minimal executable installer/status stubs that
assert arguments and emit the dependency contracts. At least one successful
integration test must use the real post-plan `install.sh`, `bin/status`, and
transaction behavior copied into the disposable repository; do not touch real
HOME.

## Done criteria

- [ ] `dot upgrade` and `dot upgrade --plan` preview only and never change HEAD
      or HOME.
- [ ] Plan/apply reject dirty, detached, non-default, ahead, and diverged
      checkouts.
- [ ] Only `origin`'s unambiguous default branch and `git merge --ff-only` are
      supported.
- [ ] Preview runs the target revision's installer with the exact safe plan
      flags from this plan and represents links under the live checkout path,
      never the temporary archive.
- [ ] Apply requires explicit confirmation, creates a recovery ref before the
      fast-forward, and runs the updated installer with safe flags.
- [ ] Successful apply records before/target/after SHAs, install transaction ID
      or `none`, and valid `dotfiles.status/v1` output.
- [ ] Failed apply preserves recovery information and never automatically resets
      Git or applies restore.
- [ ] No upgrade mode performs package, credential, TPM, hook, macOS-default, or
      branch-publication work.
- [ ] Focused Bats tests and `make check` exit `0`.
- [ ] `git diff --check` exits `0` and no out-of-scope files changed.
- [ ] `plans/README.md` marks plan 016 DONE.

## STOP conditions

Stop and report back instead of improvising if:

- Plans 014 or 015 are incomplete or their public contracts differ from those
  in "Current state".
- The remote default branch is absent/ambiguous or the installed checkout is not
  clean, attached, on that branch, and strictly behind/current.
- Previewing the target revision would require checking it out over the live
  working tree or running a mutating installer mode.
- Apply would require merge commits, rebase, reset, stash, force, or branch
  switching.
- The target installer no longer supports the exact safe flags.
- Status output contains secrets/raw provider logs or is not
  `dotfiles.status/v1`.
- Correct recovery would require automatic Git rollback or automatic restore.
- A focused verification fails twice after a reasonable fix attempt.
- Any out-of-scope file appears necessary.

## Maintenance notes

- Keep `upgrade` separate from `update`: one converges this repository and its
  managed links; the other performs broad package/repository maintenance.
- Recovery refs are intentionally retained. A later retention plan may list and
  prune them only after defining an explicit policy.
- Future machine profiles should supply installer choices rather than adding
  more upgrade flags. Until then, keep the safe no-package invocation fixed.
- Reviewers should scrutinize every Git command, the recheck immediately before
  fast-forward, temp-archive cleanup, trap exit preservation, and absence of
  automatic rollback.
