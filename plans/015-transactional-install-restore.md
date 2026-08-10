# Plan 015: Record install transactions and add a safe `dot restore`

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 2d61df6..HEAD -- install.sh bin/restore bin/dot bin/lib/transactions.sh bin/lib/symlinks.sh tests/restore.bats tests/dot.bats scripts/test-install-smoke.sh Makefile README.md bin/README.md docs/bin.md plans/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none; execute after plan 014 in this roadmap
- **Category**: direction
- **Planned at**: commit `2d61df6`, 2026-08-10

## Why this matters

The installer protects existing files by moving them into a timestamped backup
directory, but it does not record which target changed, what kind of object was
there, or how to reverse the operation. Existing symlinks are removed without
being preserved at all. A transaction journal plus preview-first restore makes
new-machine setup and configuration experimentation recoverable while refusing
to overwrite state that changed after installation.

## Current state

- `install.sh` sets one timestamped `BACKUP_DIR` per run.
- `backup_if_exists()` moves regular files/directories into that directory and
  simply removes existing symlinks.
- `create_symlink()` knows the source and absolute target but records no prior
  state and no completed-operation marker.
- The install summary prints the backup directory only when something was
  moved; there is no list, plan, or restore command.
- `bin/lib/symlinks.sh` is the trusted manifest for repository-relative sources
  and HOME-relative targets. Its pipe-delimited data is already consumed by
  both install and doctor.

Current excerpts:

```bash
# install.sh:8-13
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

source "$SCRIPT_DIR/bin/lib/symlinks.sh"
```

```bash
# install.sh:169-191
backup_if_exists() {
    local target="$1"
    local name="$2"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
        local backup_path="$BACKUP_DIR/$name"
        if [ "$PLAN_MODE" = true ]; then
            print_plan "Would back up existing $name to $backup_path"
            BACKUPS_PLANNED=$((BACKUPS_PLANNED + 1))
        else
            mkdir -p "$BACKUP_DIR"
            mv "$target" "$backup_path"
            print_warning "Backed up existing $name to $backup_path"
        fi
        return 0
    elif [ -L "$target" ]; then
        if [ "$PLAN_MODE" = true ]; then
            print_plan "Existing symlink found, would replace it"
        else
            print_info "Existing symlink found, will be replaced"
            rm -f "$target"
        fi
        return 0
    fi
}
```

```bash
# install.sh:521-528
if [ "$PLAN_MODE" = true ] && [ "$BACKUPS_PLANNED" -gt 0 ]; then
    echo -e "  ${YELLOW}Backup directory:${NC} $BACKUP_DIR"
    echo -e "  Existing files would be moved there before applying changes."
elif [ -d "$BACKUP_DIR" ]; then
    echo -e "  ${YELLOW}Backup directory:${NC} $BACKUP_DIR"
    echo -e "  Files that were replaced have been backed up there."
fi
```

Use this transaction layout under the current backup root:

```text
~/.dotfiles-backup/
  latest                     # one complete transaction ID, plain text
  20260810T153045-12345-6789/ # UTC timestamp, PID, and random suffix
    metadata                 # key=value metadata; never sourced as shell
    entries                  # pipe-delimited trusted journal records
    payload/
      0001                   # prior file or directory moved here
      0002
```

Required metadata keys are `version=1`, `id`, `created_at`, `repo_revision`, and
`state`. Allowed states are `in_progress`, `complete`, `failed`, and `restored`.
The parser must read allowlisted keys as data; it must never `source`, `eval`, or
execute transaction contents.

Each `entries` record is:

```text
sequence|target_relative_to_home|prior_kind|prior_value|installed_source_relative
```

- `prior_kind` is exactly `absent`, `file`, `directory`, or `symlink`.
- For `file`/`directory`, `prior_value` is `payload/<sequence>`.
- For `symlink`, `prior_value` is the literal previous `readlink` result.
- For `absent`, `prior_value` is empty.
- `installed_source_relative` is the trusted repo-relative source from
  `managed_symlinks_for_group`.
- Reject any field containing a newline, carriage return, pipe, an absolute
  target path, or a `..` path component. Do not attempt escaping or recovery by
  interpretation.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Focused restore tests | `bats tests/restore.bats tests/dot.bats` | all tests pass |
| Install smoke | `make install-smoke` | all install/doctor/transaction checks pass |
| Shell syntax | `bash -n install.sh bin/restore bin/lib/transactions.sh bin/dot` | exit `0` |
| ShellCheck | `shellcheck --severity=warning -x -P bin install.sh bin/restore bin/lib/transactions.sh bin/dot` | exit `0` |
| Full repository gate | `make check` | exit `0`; all Bats tests pass |

## Scope

**In scope** (the only files the executor may modify):

- `install.sh` — journal each changed target and finalize transaction state.
- `bin/lib/transactions.sh` — create shared, data-only transaction parsing,
  validation, listing, and metadata helpers.
- `bin/restore` — create the list/plan/apply CLI.
- `bin/dot` — promote `restore` to the primary command list.
- `tests/restore.bats` — create transaction and restore regression coverage.
- `tests/dot.bats` — assert restore discovery/help dispatch.
- `scripts/test-install-smoke.sh` — assert normal apply creates a complete
  transaction without touching real HOME.
- `Makefile` — add new shell files to explicit ShellCheck inputs.
- `README.md`, `bin/README.md`, `docs/bin.md` — document backup layout and safe
  restore workflow.
- `plans/README.md` — update this plan's status when complete.

`bin/lib/symlinks.sh` is listed in the drift check because it defines trusted
fields, but it is **read-only for this plan** unless a comment-only clarification
is essential. Changing managed targets is out of scope.

**Out of scope** (do not touch):

- Restoring Homebrew packages, tmux plugins, Git hooks, API-key stub contents,
  Neovim plugins, or macOS defaults. This plan restores only managed symlink
  targets changed by `install.sh`.
- Deleting transaction directories or implementing retention/pruning.
- A `--force` option. Conflicts must fail closed.
- Automatically resetting Git revisions; plan 016 handles upgrade recovery
  metadata separately.
- Migrating or guessing the meaning of historical backup folders that lack a
  versioned manifest.
- Changing the managed symlink set or introducing machine profiles.

## Git workflow

- Branch: `advisor/015-transactional-install-restore`
- Use a conventional commit such as `feat(dot): add transactional restore`.
- Keep `bin/restore` executable.
- Do not push or open a PR unless the operator asks.

## Steps

### Step 1: Add strict transaction data helpers

Create `bin/lib/transactions.sh` as a Bash library. It must:

- Define the backup root as `${DOTFILES_BACKUP_ROOT:-$HOME/.dotfiles-backup}` so
  tests can isolate it without changing the production default.
- Generate collision-resistant IDs in UTC as
  `YYYYMMDDTHHMMSS-<pid>-<random>` and refuse to reuse an existing directory.
- Validate IDs with a strict allowlist (`[0-9T-]` only) before constructing a
  path.
- Validate every relative source/target and journal field as described above.
- Read metadata with `while IFS='=' read -r key value`, accepting only the
  required keys; never source it.
- Update `state` by rewriting metadata through a temporary file in the same
  transaction directory followed by `mv`, not in-place `sed`.
- Provide helpers for enumerating transaction directories and resolving
  `latest` or an explicit validated ID without following an arbitrary path.
- Treat the plain-text `latest` file as untrusted input and validate it before
  use.

The library must not mutate HOME merely by being sourced.

**Verify**: `bash -n bin/lib/transactions.sh && shellcheck --severity=warning -x -P bin bin/lib/transactions.sh` → exit `0`.

### Step 2: Journal installer changes before replacing targets

Refactor only the mutation boundary in `install.sh`:

1. Keep `--plan` fully non-mutating: it creates no backup root, transaction,
   metadata, `latest` file, or payload.
2. Lazily create a transaction on the first target that actually needs a
   change. A run where every symlink is already correct creates no transaction.
3. Write metadata with `state=in_progress` before the first mutation.
4. For each target, inspect its exact prior kind and allocate the next sequence:
   - Existing non-symlink file/directory: set its prior value to
     `payload/<sequence>`.
   - Existing symlink: capture its raw `readlink` value.
   - Missing path: record `absent`.
   - FIFO, socket, device node, or any other unsupported filesystem kind: stop
     before journaling or mutation and report the exact target path (not its
     contents).
5. Append and flush the complete journal record **before any move, removal, or
   link creation**. Never rewrite earlier records.
6. After the record is durable, move a prior file/directory to its payload or
   remove a prior symlink, then create the expected repository symlink using the
   existing interactive and counter behavior.
7. Use an EXIT trap to mark an active transaction `failed` when the installer
   exits non-zero. Do not override another cleanup trap without preserving it.
8. On successful completion, atomically mark the transaction `complete`, then
   atomically write its ID to `~/.dotfiles-backup/latest`.

Keep old summary language understandable, but add stable lines:

```text
Transaction: <id>
Restore preview: dot restore --plan <id>
```

Do not print a transaction ID when no changes occurred.

**Verify**: focused install cases in `tests/restore.bats` prove plan/no-op runs
create nothing and changed runs create valid complete metadata and entries.

### Step 3: Implement preview, list, and conflict-safe restore

Create executable `bin/restore` with this exact CLI:

```text
dot restore --list
dot restore --plan [latest|ID]
dot restore --apply [latest|ID] [--yes]
dot restore --help
```

No action is implied when only `dot restore` is run; print help and exit `0`.
Unknown or incompatible flags exit `64`.

Behavior:

- `--list` prints ID, state, creation time, repo revision, and entry count. It
  never traverses outside the configured backup root and never prints prior
  symlink destinations or payload contents.
- `--plan` validates metadata and every journal record, then prints one action
  per target without mutation. It accepts `complete` or `failed` transactions;
  a failed transaction may contain a valid partial journal.
- `--apply` performs the same full validation and preflight **before changing
  any target**, prompts unless `--yes`, and applies entries in reverse sequence.
- For each entry, accept only these current states:
  1. The target is the expected managed symlink: restore its prior state.
  2. The journaled mutation never began: a prior file/directory still exists at
     the target while its payload is absent, the exact prior symlink is still
     present, or an `absent` target remains absent. Leave it untouched and
     report an already-original/no-op state; do not claim content identity that
     was never journaled.
  3. A file/directory payload exists while the target is absent (interrupted
     install before link creation): move it back.
  4. A prior symlink was removed but the managed link was never created: when
     the target is absent, recreate the exact journaled prior symlink.
- Any other current state is a conflict. Abort the **entire** apply during
  preflight; do not partially restore and do not offer force.
- `prior_kind=absent`: remove only the exact expected managed symlink.
- `prior_kind=symlink`: remove only the exact expected managed symlink, then
  recreate the recorded raw link target.
- `prior_kind=file|directory`: remove only the expected managed symlink if
  present, then move the recorded payload back to the HOME-relative target.
- After successful apply, atomically mark metadata `state=restored`. Keep the
  journal and any now-empty payload directory for audit; never delete the
  transaction.
- A second apply of a restored transaction must refuse with a clear message;
  `--plan` may report that it is already restored.

All paths must remain under the explicit HOME and backup roots after lexical
validation. Do not canonicalize a target through its current symlink before
deciding what to remove.

**Verify**: `bats tests/restore.bats` → original files, directories, relative
symlinks, absolute symlinks, and absent targets restore correctly; conflicts
leave every target untouched.

### Step 4: Wire `dot`, smoke coverage, and documentation

- Add `restore` to `bin/dot` primary descriptions/order and verify normal
  dispatch.
- Add `bin/restore` and `bin/lib/transactions.sh` to `SHELLCHECK_FILES`.
- Extend `scripts/test-install-smoke.sh` so its temp-HOME apply asserts:
  - `~/.dotfiles-backup/latest` names a directory.
  - metadata is version 1 and state complete.
  - `dot restore --plan latest` exits `0` without modifying installed links.
- Document that historical timestamped folders without `metadata` remain manual
  backups and are never inferred by restore.
- Document the exact list/plan/apply commands and the conflict refusal policy.

**Verify**: `make install-smoke && bats tests/dot.bats tests/restore.bats` → all
checks pass.

### Step 5: Run the complete gate and inspect scope

Format only changed shell files, then run the repository gate.

**Verify**:

```bash
shfmt -i 4 -ci -w install.sh bin/restore bin/lib/transactions.sh bin/dot tests/restore.bats tests/dot.bats scripts/test-install-smoke.sh
make check
git diff --check
git status --short
```

Expected: every command exits `0`; status lists only files in this plan's
in-scope list plus `plans/README.md` if updated.

## Test plan

Create `tests/restore.bats`, following the temp-HOME pattern in
`tests/doctor.bats` and `scripts/test-install-smoke.sh`. Cover at minimum:

1. Installer plan mode and already-correct no-op mode create no transaction.
2. Installation over an existing regular file preserves and journals it.
3. Installation over a directory preserves the entire directory tree.
4. Installation over relative and absolute symlinks records raw link targets.
5. An originally absent target is removed during restore.
6. `latest` resolves only a validated complete transaction ID.
7. `--list` omits payload contents and prior symlink targets.
8. `--plan` produces actions but byte-for-byte leaves HOME and metadata alone.
9. `--apply --yes` restores all prior kinds in reverse order and marks restored.
10. A target modified after installation causes full preflight failure with no
    partial changes.
11. Invalid IDs, traversal fields, pipes/newlines, unsupported versions, and
    malformed metadata are rejected.
12. A synthetic failed/partial transaction is safely previewed and restored only
    when its current-state preconditions match.
13. A second apply refuses and preserves the already-restored state.
14. An unsupported FIFO/socket-like target stops installation before mutation.

All tests must set both `HOME` and `DOTFILES_BACKUP_ROOT` to disposable explicit
paths. Never inspect or mutate the operator's real backup root.

## Done criteria

- [ ] Plan and no-op installs create no transaction artifacts.
- [ ] Every changed managed symlink target gets a version-1 journal record with
      its exact prior kind.
- [ ] Existing file/directory contents and raw symlink targets are recoverable.
- [ ] Completed installs atomically update the validated `latest` ID.
- [ ] Failed installs retain an inspectable `failed` transaction.
- [ ] `dot restore --list`, `--plan`, and `--apply` implement the documented
      CLI and never infer legacy backups.
- [ ] Restore preflights all entries and refuses conflicts without partial work.
- [ ] No transaction parser uses `source`, `eval`, or unvalidated path input.
- [ ] Focused Bats tests, install smoke, and `make check` exit `0`.
- [ ] `git diff --check` exits `0` and no out-of-scope files changed.
- [ ] `plans/README.md` marks plan 015 DONE.

## STOP conditions

Stop and report back instead of improvising if:

- Supporting a current target requires a force-overwrite or best-effort merge.
- A transaction field needs arbitrary escaping or evaluation; prefer rejecting
  unsupported path characters.
- Restore cannot verify the current target is either the expected managed link,
  the exact untouched prior state, or a recognized interrupted-install state.
- Existing API-key files, Homebrew state, Git configuration contents, macOS
  defaults, or other non-symlink state would need to be copied into the journal.
- A payload or target path cannot be proven to stay within the explicit backup
  root or HOME.
- A focused verification fails twice after a reasonable fix attempt.
- Any out-of-scope file appears necessary.

## Maintenance notes

- The version-1 journal is a durable recovery interface. Future fields require
  a version bump or backward-compatible parser change with fixtures.
- Never add secret contents to metadata, entries, or diagnostic output.
- Reviewers should focus on validation-before-mutation, reverse-order restore,
  trap behavior on failure, and the absence of partial restores after conflict.
- Plan 016 consumes only the `latest` transaction ID and public restore CLI; it
  must not parse payloads or duplicate restore logic.
