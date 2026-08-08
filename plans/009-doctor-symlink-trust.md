# Plan 009: Make doctor trustworthy for relative symlinks

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 5d08aa5..HEAD -- bin/doctor .github/workflows/smoke.yml`
> If in-scope files drifted, re-read live code before proceeding.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `5d08aa5`, 2026-08-08

## Why this matters

`doctor` compares `readlink` strings literally to absolute `$DOTFILES_DIR/...`
paths. Valid relative symlinks (`../dotfiles/yazi`) fail even when they resolve
to the correct target. That produces a permanently red doctor (~10 false
failures) so the operator ignores real issues. TPM missing is also a hard
failure though optional for many workflows.

## Current state

```bash
# bin/doctor check_symlink (~41–57)
if [ "$(readlink "$target")" != "$expected" ]; then
    record_failure "$label points to $(readlink "$target") instead of $expected"
fi

# TPM (~143 area)
check_path_exists "TPM" "$HOME/.tmux/plugins/tpm"  # record_failure if missing
```

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Check | `make check` | exit 0 |
| Doctor | `bin/doctor --skip-tools` | exit 0 if managed symlinks resolve correctly; TPM warn OK |
| Parse | `bash -n bin/doctor` | exit 0 |

## Scope

**In scope**:
- `bin/doctor` — resolve symlink targets for comparison; TPM soft warning
- Optional comment in CI if doctor behavior change needs documenting

**Out of scope**:
- Forcing all home configs to be re-symlinked
- Changing install.sh symlink creation policy
- Plan 007 agents

## Git workflow

- Branch: `advisor/009-doctor-symlink-trust`
- Commit: `fix: resolve doctor symlink targets for relative links`
- Do NOT push/PR unless asked

## Steps

### Step 1: Resolve paths in `check_symlink`

Add a small helper (inline or next to `check_symlink`) that returns a canonical
absolute path using `python3` (available on macOS CI and developer machines):

```bash
resolve_path() {
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null
}
```

In `check_symlink`:

1. If target is not a symlink → keep `record_failure` (unchanged).
2. Resolve both the symlink path and the expected path with `resolve_path`.
3. If either resolution fails → failure with clear message.
4. If resolved paths are equal → success (print resolved expected or short form).
5. Else → failure showing both resolved paths (and optional raw readlink for debug).

**Verify**: Create a temp dir with `ln -s relative/path` and unit-test mentally via:

```bash
# On a machine with relative nvim/yazi links that previously failed:
bin/doctor --skip-tools 2>&1 | rg -i 'Yazi|Ghostty|Neovim|Zsh config|points to' | head -20
# Expect success for links that resolve to the repo
```

### Step 2: TPM as warning

Change TPM check from `check_path_exists` (failure) to:

```bash
if [ -e "$HOME/.tmux/plugins/tpm" ]; then
  print_success "TPM exists: ..."
else
  record_warning "TPM is missing (optional; install via install.sh tmux step)"
fi
```

**Verify**: `bin/doctor --skip-tools` with no TPM → warning, not failure for TPM alone.

### Step 3: make check

```bash
make check
bash -n bin/doctor
```

## Done criteria

- [ ] Relative symlinks that resolve to `$DOTFILES_DIR/...` pass doctor
- [ ] Missing TPM is a warning, not a failure
- [ ] `make check` exit 0
- [ ] `plans/README.md` 009 → DONE

## STOP conditions

- `python3` unavailable on CI and no portable fallback — add `readlink -f`/`realpath` fallback chain before inventing something else
- CI install-smoke fails because doctor became stricter elsewhere — fix doctor, don’t skip doctor in CI

## Maintenance notes

- Reviewers: path comparison must not follow a malicious symlink outside the expected tree in a way that marks wrong targets OK — comparing realpath of expected repo path vs realpath of link is correct when expected is always under DOTFILES_DIR
