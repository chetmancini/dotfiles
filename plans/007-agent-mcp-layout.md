# Plan 007: Unify and structure agent / MCP config

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat a52b4b5..HEAD -- claude/ mcp.json install.sh bin/lib/symlinks.sh README.md CLAUDE.md`

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plan 003 helpful for secrets story; not hard-required
- **Category**: direction
- **Planned at**: commit `a52b4b5`, 2026-08-07

## Why this matters

AI tooling is a first-class part of this machine (Claude configs under
`claude/`, root `mcp.json`, Grok paths, many AI casks). Layout and docs are
ad hoc; `mcp.json` still has placeholder filesystem paths
(`/Users/username/Desktop`). Modernizing means **predictable layout**,
**documented install/symlink expectations**, and **no placeholder secrets**.

## Current state

```text
claude/
  agents/     # code-reviewer, product-manager, ...
  commands/   # add-linear-ticket.md
mcp.json      # sample MCP servers (fetch disabled, filesystem placeholders)
```

`mcp.json` excerpt shape:

```json
{
  "mcpServers": {
    "fetch": { "command": "uvx", "args": ["mcp-server-fetch"], "disabled": true },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem",
               "/Users/username/Desktop", "/path/to/other/allowed/dir"]
    }
  }
}
```

No install.sh wiring for `mcp.json` or `claude/` into `~/.claude` etc. at plan time
(confirm with `rg -n 'mcp|claude' install.sh bin/lib/symlinks.sh`).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Check | `make check` | exit 0 |
| JSON valid | `python3 -m json.tool mcp.json` (or new path) | exit 0 |
| Doctor | `bin/doctor --skip-tools` | OK with any new checks soft |

## Scope

**In scope**:
- Repo layout for agent configs (see target below)
- `mcp.json` → safer sample (no fake user paths; use `$HOME` documentation instead of invalid literals)
- `install.sh` / `symlinks.sh` **optional** symlinks for Claude config if paths are standard
- `docs/agents.md` or README section
- `CLAUDE.md` pointer
- doctor soft checks for optional agent dirs

**Out of scope**:
- Implementing new MCP servers
- Committing real MCP tokens
- Unifying every AI product’s config format (Cursor vs Claude vs Grok) fully — document differences instead
- Moving `~/.grok` managed files that are outside this repo

## Git workflow

- Branch: `advisor/007-agent-mcp-layout`
- Do NOT push/PR unless asked

## Target layout

Prefer **minimal move** (docs + sample cleanup) unless moves are easy:

**Option A (preferred if low churn)**: keep `claude/` at root; move `mcp.json` → `config/mcp.json.example` or `mcp/mcp.json.example`; document copy/symlink.

**Option B**: 

```text
agents/
  claude/     # was claude/
  mcp.example.json
```

Only choose B if executor updates all references and install paths; otherwise A.

## Steps

### Step 1: Inventory live tool paths

```bash
ls -la claude mcp.json
ls -la ~/.claude 2>/dev/null | head -20 || true
ls -la ~/.config/claude 2>/dev/null | head || true
# Note what the operator already uses — do not overwrite without backup
```

**Verify**: inventory written into commit message notes.

### Step 2: Sanitize example MCP config

1. Rename tracked file to clearly be an **example** if it isn’t live:
   - e.g. `mcp.json.example` or `config/mcp.json.example`
2. Replace placeholder absolute paths with documentation comments **JSON cannot comment** — so use obviously fake paths like `/ABS/PATH/to/allowed/dir` and README instructions, or empty `args` with README.
3. Keep `fetch` disabled by default.
4. Ensure file is valid JSON.

If the operator **relies** on root `mcp.json` as a real config, STOP and report
rather than renaming out from under them — instead add `mcp.json.example` beside it
and gitignore live overrides if needed.

**Verify**: `python3 -m json.tool <example> >/dev/null`.

### Step 3: Document Claude agents/commands

- README or `docs/agents.md`: what lives under `claude/agents`, `claude/commands`
- How to install: symlink or copy to Claude’s expected directory (look up current
  Claude Code path at execution time — common patterns include `~/.claude/` —
  **verify on machine**, don’t invent)
- If path confirmed, add optional symlink entries to `symlinks.sh` gated or
  documented as manual

**Verify**: doc paths match files that exist in repo.

### Step 4: Secrets cross-link

Point agent docs at plan 003 secrets flow: agents should use environment
variables loaded via 1Password, not committed keys.

**Verify**: docs mention `api_keys_1password` / op without secret values.

### Step 5: Doctor soft checks

- If example exists, don’t require live MCP config
- Optional: warn if `claude/` missing when expected

**Verify**: `bin/doctor --skip-tools` exit 0.

### Step 6: make check

JSON/TOML as applicable; shell if install changed.

## Test plan

- Example MCP JSON validates
- Docs render accurate tree listing (`ls` matches doc)
- No secrets in tracked agent files (`rg` for `sk-` / `api_key=` patterns — clean)

## Done criteria

- [ ] MCP example is clearly example-shaped and valid JSON
- [ ] Agent layout documented; install story clear
- [ ] No placeholder `/Users/username` paths left in tracked config without explanation
- [ ] Secrets guidance cross-linked
- [ ] `make check` exit 0
- [ ] `plans/README.md` 007 → DONE

## STOP conditions

- Live MCP config with secrets is tracked in git — **do not print**; report for
  rotation and gitignore immediately
- Claude’s on-disk config path cannot be verified — document manual copy only;
  don’t invent symlink targets
- Moving `claude/` would break operator workflows mid-session — prefer docs-only

## Maintenance notes

- New agent markdown files go under `claude/agents/` (or new layout)
- Reviewers: ensure examples aren’t real credentials
- Follow-up: shared MCP across Cursor/Claude via one example and per-tool adapters
