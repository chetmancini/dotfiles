# Agents & MCP

> Claude Code agents, commands, and Model Context Protocol (MCP) example config.

## Overview

AI tooling is tracked but not auto-installed. Live secrets are never committed.

| Path | Purpose | Tracked? |
|------|---------|----------|
| `claude/agents/*.md` | Claude agent definitions (reviewer, pm, etc.) | yes |
| `claude/commands/*.md` | Claude slash-commands | yes |
| `mcp.json.example` | Sanitized MCP servers example (fetch + filesystem) | yes |
| `mcp.json` | Live MCP config (gitignored, copy from example) | no — gitignored |

## Claude agents & commands

```
claude/
  agents/
    code-reviewer.md          # meticulous principal-engineer review
    product-manager.md
    senior-software-engineer.md
    ux-designer.md
  commands/
    add-linear-ticket.md      # create Linear ticket from context
```

**Install:** Claude Code reads agents/commands from its own config directory (commonly `~/.claude/` or project-local `.claude/` — verify with `ls -la ~/.claude` on your machine). This repo keeps the source in `claude/` at the repo root and does not auto-symlink to avoid overwriting your live `~/.claude`:

```bash
# manual copy/symlink when you want dotfiles to own the config
cp -R ~/dotfiles/claude ~/.claude      # or
ln -s ~/dotfiles/claude ~/.claude      # after backing up existing ~/.claude
```

Add new agents as `claude/agents/<name>.md`; new commands as `claude/commands/<name>.md`.

## MCP config

`mcp.json.example` is valid JSON with no real paths or secrets:

```json
{
  "mcpServers": {
    "fetch": { "command": "uvx", "args": ["mcp-server-fetch"], "disabled": true },
    "filesystem": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", "/REPLACE/WITH/ALLOWED/DIR"] }
  }
}
```

- `fetch` is `disabled: true` by default.
- `filesystem` allows exactly one placeholder dir — replace `/REPLACE/WITH/ALLOWED/DIR` with an absolute allowed path (add more entries as needed) and remove the placeholder if you don't use filesystem.

**Use:**

```bash
cp mcp.json.example mcp.json              # then edit mcp.json with real paths
# or, for Claude Code's expected location:
cp mcp.json.example ~/.config/claude/mcp.json  # verify your tool's path
python3 -m json.tool mcp.json >/dev/null  # validate
```

`mcp.json` is gitignored (`/.gitignore` `mcp.json`) so your live file with real paths never gets committed.

## Secrets

Agents and MCP servers must use environment variables, not committed keys:

- Store keys in 1Password vault **Dot Secrets** (see `api_keys_1password.sh.template`).
- Export via `op_secret "Vault/Item/field"` in `api_keys_1password.sh` (loaded by `zsh/secrets.zsh`).
- Validate with `validate-api-keys` (never prints values).

Never commit `api_keys.sh` or `api_keys_1password.sh` (both gitignored) and never put `sk-` or `api_key=` literals in `claude/` or `mcp.json*` (checked by `bin/doctor` soft check).

## Doctor checks

`bin/doctor --skip-tools` soft-checks (warnings, not failures):

- `mcp.json.example` is valid JSON
- `claude/agents/` and `claude/commands/` exist (warns if missing)
- No `sk-...` or `api_key=` literals in tracked `claude/` or `mcp.json.example`

Full `make check` also validates `mcp.json.example` JSON.
