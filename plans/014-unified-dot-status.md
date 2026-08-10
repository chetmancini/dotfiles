# Plan 014: Add a unified, structured `dot status` command

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 2d61df6..HEAD -- bin/status bin/dot bin/doctor bin/brew-sync bin/repo-report bin/validate-api-keys tests/status.bats tests/repo-report.bats tests/dot.bats Makefile README.md bin/README.md docs/bin.md plans/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `2d61df6`, 2026-08-10

## Why this matters

The repository already knows how to check installed symlinks, dependencies,
Homebrew drift, and repository state, but those answers live behind separate
commands with unrelated output and exit behavior. A fast `dot status` should
answer "is this machine ready?" without duplicating those checks. A small,
versioned JSON surface also gives later lifecycle commands a stable health gate
without exposing API-key values or scraping colorized human output.

## Current state

- `bin/dot` is the public dispatcher. Its primary command list is maintained in
  `primary_description()` and `print_help()`.
- `bin/doctor` checks installed state and exits `1` only when `FAILURES > 0`;
  ordinary warnings remain exit `0`.
- `bin/brew-sync --check` exits `0` when core Homebrew state is synchronized and
  `1` when drift or outdated packages are found.
- `bin/repo-report` calculates `dirty_repos`, but currently prints a summary and
  always exits `0` after a successful scan.
- `bin/validate-api-keys --json` is the repo's exemplar for a command that emits
  machine-readable output without requiring `jq`. It is deliberately **not** a
  default `dot status` provider because it performs credential-bearing network
  checks.

Current excerpts:

```bash
# bin/dot:27-36
primary_description() {
    case "$1" in
        install) echo "Run install.sh (bootstrap / re-link; pass flags through)" ;;
        doctor) echo "Verify dotfiles installation health" ;;
        brew-sync) echo "Check and sync Brewfile with installed packages" ;;
        update | update-everything) echo "Run system/package update routine" ;;
        good-morning) echo "Run a configurable set of tasks to start the day" ;;
        cheatsheet) echo "Quick reference for aliases, keybindings, and functions" ;;
        dashboard) echo "Show useful information at a glance" ;;
        *) return 1 ;;
    esac
}
```

```bash
# bin/doctor:288-297
if [ "$WARNINGS" -gt 0 ]; then
    print_info "Warnings: $WARNINGS"
fi

if [ "$FAILURES" -gt 0 ]; then
    print_error "Failures: $FAILURES"
    exit 1
fi

print_success "Dotfiles look healthy"
```

```bash
# bin/repo-report:188-190
echo -e "${BLUE}━━━ Summary ━━━${NC}"
echo -e "  Total: $total_repos  ${GREEN}Clean: $clean_repos${NC}  ${RED}Dirty: $dirty_repos${NC}"
```

The initial status schema must be exactly:

```json
{
  "schema": "dotfiles.status/v1",
  "overall_status": "ok",
  "deep": false,
  "components": [
    {
      "id": "doctor",
      "status": "ok",
      "exit_code": 0,
      "summary": "Installed dotfiles are healthy",
      "remediation": "dot doctor --skip-tools"
    }
  ]
}
```

Allowed component statuses are `ok`, `warning`, `error`, and `skipped`.
`overall_status` is `error` if any component is `error`, otherwise `warning` if
any component is `warning`, otherwise `ok`. A skipped optional component does
not degrade the overall status.

`dot status` exit codes are a public contract:

| Exit | Meaning |
|------|---------|
| `0` | All executed components are healthy; optional checks may be skipped |
| `1` | Drift or another actionable warning exists |
| `2` | A required check could not run or reported a hard failure |
| `64` | Command-line usage error |

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Focused status tests | `bats tests/status.bats tests/repo-report.bats tests/dot.bats` | all tests pass |
| JSON validation | `HOME="$(mktemp -d)" bin/status --json 2>/dev/null \| python3 -m json.tool >/dev/null` | JSON parser exits `0` (status itself may report unhealthy for the empty HOME, so capture it separately in tests) |
| Shell syntax | `bash -n bin/status bin/repo-report bin/dot` | exit `0` |
| ShellCheck | `shellcheck --severity=warning -x -P bin bin/status bin/repo-report bin/dot` | exit `0` |
| Full repository gate | `make check` | exit `0`; all Bats tests pass |

## Scope

**In scope** (the only files the executor may modify):

- `bin/status` — create the aggregator.
- `bin/repo-report` — add check-mode exit semantics while preserving existing
  default behavior and output.
- `bin/dot` — promote `status` to the primary command list.
- `tests/status.bats` — create focused aggregator/JSON/exit-code coverage.
- `tests/repo-report.bats` — create coverage for the new check-mode contract.
- `tests/dot.bats` — assert `status` discovery and help dispatch.
- `Makefile` — add new executable scripts to explicit ShellCheck inputs.
- `README.md`, `bin/README.md`, `docs/bin.md` — document the status surface and
  its fast/deep distinction.
- `plans/README.md` — update this plan's status when complete.

**Out of scope** (do not touch):

- `bin/doctor`, `bin/brew-sync`, and `bin/validate-api-keys`. Invoke them as
  providers; do not redesign their human output or add JSON modes in this plan.
- Running `validate-api-keys` from `dot status`; credential/network validation
  must remain an explicit operator action.
- Automatic repairs, package installation, repository fetch/pull, or any other
  mutation. `status` is read-only.
- A generic plugin framework or command registry refactor for `bin/dot`.
- macOS preference checks, agent configuration adapters, or machine profiles.

## Git workflow

- Branch: `advisor/014-unified-dot-status`
- Use a conventional commit such as `feat(dot): add unified machine status`.
- Keep the new command executable.
- Do not push or open a PR unless the operator asks.

## Steps

### Step 1: Give `repo-report` opt-in health-check semantics

Add `--check` to `bin/repo-report` without changing its existing default exit
behavior:

- With no `--check`, retain today's exit `0` after any successful scan even if
  repositories are dirty.
- With `--check`, exit `0` when `dirty_repos == 0`, exit `1` when one or more
  repositories have issues, and exit `2` when there are no scan directories or
  a requested directory cannot be scanned.
- Keep `-d/--dirty`, `-q/--quiet`, positional directories, and the existing
  human summary compatible.
- Update `--help` with the new option and exit meanings.

Do not use `git fetch`; ahead/behind stays relative to locally known upstream
refs, as it is today.

**Verify**: `bats tests/repo-report.bats` → tests cover clean, dirty, missing
directory, and legacy non-check exit behavior and all pass.

### Step 2: Implement the fast local status aggregator

Create executable `bin/status` using the repo's Bash conventions:

- Resolve `SCRIPT_DIR` through symlinks the same way as `bin/dot` and
  `bin/brew-sync`, then source `bin/lib/helpers.sh`.
- Accept `--json`, `--deep`, and `-h/--help`; reject unknown arguments with exit
  `64`.
- Default mode runs only:
  1. `doctor --skip-tools`.
  2. `repo-report --check --dirty --quiet` against the existing default roots.
- If neither `~/code` nor `~/norm` exists, mark `repositories` as `skipped`
  rather than failing the whole command.
- Capture each provider's stdout/stderr in a `mktemp -d` directory and clean it
  with a trap. Never write status artifacts into the repository.
- Determine semantics from provider exit codes, not from colorized text:
  - doctor `0` → `ok`; doctor non-zero → `error`.
  - repo-report `0` → `ok`; `1` → `warning`; `2+` → `error`.
- Human output is a concise one-line result per component plus the final
  overall status and remediation command. Do not dump full provider output by
  default; on warning/error, tell the user which underlying command to run.

Use stable component IDs `doctor` and `repositories`. Summaries and remediation
strings must be static safe text; they must not contain captured command output,
HOME paths, repository names, environment values, or secret-adjacent data.

**Verify**: `bats tests/status.bats` → fast mode tests pass and prove no `brew`
or credential validator invocation occurs.

### Step 3: Add opt-in deep checks

When `--deep` is supplied:

- Run `doctor --strict` **without** `--skip-tools` so missing commands become a
  hard deep-readiness failure instead of disappearing inside doctor's
  otherwise-successful warning output.
- Add a `homebrew` component that invokes `brew-sync --check` only when `brew`
  is available.
- If `brew` is unavailable, mark `homebrew` as `skipped` and keep the overall
  status unchanged.
- Map Homebrew exits: `0` → `ok`, `1` → `warning`, anything else → `error`.
- Do not make deep mode call `validate-api-keys`, update Homebrew, fetch Git
  remotes, or access calendar/weather/GitHub APIs.

**Verify**: `bats tests/status.bats` → fake-PATH tests cover Homebrew healthy,
drift, absent, and execution-error cases and all pass without using live Brew.

### Step 4: Emit deterministic JSON

Implement `--json` using the exact `dotfiles.status/v1` shape above:

- Emit JSON only on stdout; route diagnostics to stderr.
- Preserve component order: `doctor`, `repositories`, then `homebrew` in deep
  mode.
- Use `python3` only for correct JSON encoding of the already-sanitized static
  fields, or implement complete escaping including backslash, quote, newline,
  carriage return, and tab. Do not reproduce the partial escaping pattern from
  `validate-api-keys` for arbitrary captured output.
- Never put captured provider output in JSON.
- Human and JSON modes must produce the same component/overall statuses and
  exit code.

Tests must parse JSON with Python and assert values, not compare whitespace or
snapshot a formatted document.

**Verify**: `bats tests/status.bats` → schema, order, status aggregation, clean
stdout, and exit-code tests all pass.

### Step 5: Wire the public CLI and documentation

- Add `status` to `primary_description()` and the primary order in `bin/dot`.
- Ensure `dot status --help`, `dot status --json`, and `dot status --deep` pass
  through to `bin/status` normally; do not special-case execution beyond the
  existing dispatcher.
- Add `bin/status` to `SHELLCHECK_FILES` in `Makefile`.
- Document that default status is local/read-only and `--deep` adds tool and
  Homebrew checks. Document exit codes and the JSON schema identifier in
  `docs/bin.md`; keep README and `bin/README.md` concise.

**Verify**: `bats tests/dot.bats tests/status.bats` → dispatcher and status
tests pass.

### Step 6: Run the full gate and inspect scope

Run formatting only on the files changed by this plan, then run the repository
gate.

**Verify**:

```bash
shfmt -i 4 -ci -w bin/status bin/repo-report bin/dot tests/status.bats tests/repo-report.bats tests/dot.bats
make check
git diff --check
git status --short
```

Expected: every command exits `0`; status lists only files in this plan's
in-scope list plus `plans/README.md` if the executor updated it.

## Test plan

Create `tests/status.bats`, modeled on `tests/dot.bats` and
`tests/doctor.bats`, with fake commands and temporary HOME directories. It must
cover:

1. `--help` and unknown-option exit `64`.
2. Fast-mode healthy result and provider order.
3. Doctor failure → component/overall `error`, exit `2`.
4. Dirty repositories → `warning`, exit `1`.
5. Missing default repo roots → `repositories: skipped`, not an error.
6. `--deep` with Brew absent → `homebrew: skipped`.
7. `--deep` with fake Brew healthy/drift/error exit mappings.
8. JSON parses and matches `dotfiles.status/v1`; stdout contains JSON only.
9. Fast mode never calls Brew or `validate-api-keys`.

Create `tests/repo-report.bats` with isolated Git repositories and fixed local
identity. It must cover clean and dirty `--check` exits, missing roots, and the
legacy behavior where a dirty report without `--check` still exits `0`.

Do not use the operator's real repositories, Homebrew installation, network, or
credentials in tests.

## Done criteria

- [ ] `dot help` lists `status` as a primary command.
- [ ] `dot status` is read-only, fast, and never performs network/credential
      checks.
- [ ] `dot status --deep` adds doctor tool and Homebrew drift checks only.
- [ ] `dot status --json` emits valid `dotfiles.status/v1` JSON with no captured
      provider output.
- [ ] Exit codes exactly match the documented `0/1/2/64` contract.
- [ ] `repo-report --check` distinguishes clean, dirty, and execution-error
      outcomes without changing legacy default behavior.
- [ ] Focused Bats tests and `make check` exit `0`.
- [ ] `git diff --check` exits `0` and no out-of-scope files changed.
- [ ] `plans/README.md` marks plan 014 DONE.

## STOP conditions

Stop and report back instead of improvising if:

- An existing provider must be made mutating or network-active for status to
  work.
- Correct JSON would require including raw provider output, environment values,
  repository paths, or any secret-bearing material.
- `repo-report --check` cannot preserve the existing default exit behavior.
- Python 3 is unavailable in the repository's supported doctor/install
  environment and complete JSON escaping cannot be implemented safely in Bash.
- The status command needs to change the public output or exit behavior of
  doctor or brew-sync.
- A focused verification fails twice after a reasonable fix attempt.
- Any out-of-scope file appears necessary.

## Maintenance notes

- Treat `dotfiles.status/v1` and the status exit codes as public interfaces;
  future consumers include plan 016's guarded upgrade workflow.
- New providers must be read-only, have bounded runtime, and define explicit
  exit mappings before joining default status.
- Keep credentials opt-in. A future `--credentials` mode, if desired, needs a
  separate security review and must consume only sanitized validator output.
- Reviewers should scrutinize stdout/stderr separation and ensure tests cannot
  touch the operator's HOME, repositories, Homebrew, or network.
