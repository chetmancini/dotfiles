# Plan 002: Modularize `.zshrc` and drop oh-my-zsh

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat a52b4b5..HEAD -- .zshrc chetmancini.zsh-theme install.sh bin/doctor bin/lib/symlinks.sh Brewfile Makefile .gitignore README.md CLAUDE.md`
> If in-scope files drifted, re-read live code before proceeding.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: plan 001 recommended (mise-only version managers); can proceed if 001 incomplete but then preserve whatever version-manager block exists
- **Category**: tech-debt
- **Planned at**: commit `a52b4b5`, 2026-08-07

## Why this matters

`.zshrc` is a **663-line monolith** mixing PATH, aliases, git helpers, fzf
widgets, version managers, completions, and a cmatrix screensaver. Oh-my-zsh is
vendored as a full git clone primarily to source **one** plugin
(`history-substring-search`); the theme is already custom and git prompt is
hand-rolled in `.zshrc`. That clone bloats the repo clone story, confuses
`doctor`/`install.sh`, and blocks a clean module layout.

This plan splits the shell into sourced modules under `zsh/` and removes the
oh-my-zsh dependency in favor of Homebrew’s zsh plugins (already used for
autosuggestions and syntax-highlighting).

## Current state

- `.zshrc` — sole shell entry (663 lines). Sets `DOTFILES_DIR`, `ZSH=.../oh-my-zsh`,
  sources theme + history-substring-search from OMZ, builds PATH, aliases,
  functions, fzf/zoxide, lazy managers, mise, autosuggestions/syntax-highlighting.
- `chetmancini.zsh-theme` — custom λ prompt; uses `git_prompt_info` defined in `.zshrc`
- `oh-my-zsh/` — gitignored clone (`/.oh-my-zsh` and `oh-my-zsh` in `.gitignore`)
- `install.sh` — `install_oh_my_zsh` clones OMZ and symlinks theme into
  `oh-my-zsh/custom/themes/`
- `bin/doctor` — requires OMZ checkout + theme symlink under OMZ custom themes
- `Brewfile` — already has `zsh-autosuggestions`, `zsh-syntax-highlighting`
- `Makefile` `ZSH_FILES` — `.zshrc chetmancini.zsh-theme forge-zsh.sh linux_specific.sh mac_specific.sh`

OMZ usage in `.zshrc` today:

```zsh
export ZSH="$DOTFILES_DIR/oh-my-zsh"
# ...
[ -f "$DOTFILES_DIR/chetmancini.zsh-theme" ] && source "$DOTFILES_DIR/chetmancini.zsh-theme"
[ -f "$ZSH/plugins/history-substring-search/history-substring-search.zsh" ] && \
  source "$ZSH/plugins/history-substring-search/history-substring-search.zsh"
```

**Conventions**: `DOTFILES_DIR` resolved from the sourced file path so configs
work outside `~/dotfiles`. Platform files: `mac_specific.sh` / `linux_specific.sh`.
Secrets: `api_keys.sh` / `api_keys_1password.sh` (gitignored). Cached `compinit`.
Autosuggestions + syntax-highlighting **must remain last**.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Full check | `make check` | exit 0 |
| Zsh parse all modules | `zsh -n .zshrc` and each new `zsh/*.zsh` | exit 0 |
| Doctor | `bin/doctor` | exit 0 or only pre-existing warnings; no OMZ required |
| Install dry-run | `./install.sh --plan --skip-brew` | no “clone oh-my-zsh” step (after removal) |
| Startup smoke | `zsh -ic 'echo OK; type git_prompt_info'` | OK; function exists |

## Scope

**In scope**:
- `.zshrc` (becomes thin orchestrator)
- New directory `zsh/` and modules under it
- `chetmancini.zsh-theme` (path updates only if needed; may move to `zsh/theme.zsh`)
- `install.sh` — remove or no-op OMZ install; stop linking theme into OMZ
- `bin/doctor` — drop OMZ path checks; verify new module layout / theme source
- `Brewfile` — add `zsh-history-substring-search` if available as formula; else vendor single file under `zsh/vendor/`
- `Makefile` — extend `ZSH_FILES` to new modules
- `.gitignore` — remove obsolete OMZ entries only if clone no longer used; keep if harmless
- `README.md`, `CLAUDE.md` — shell architecture bullets (minimal)
- `bin/lib/symlinks.sh` — only if a new symlink is required (prefer sourcing from repo path via `DOTFILES_DIR`, not new home symlinks)

**Out of scope**:
- Rewriting prompt to starship/oh-my-posh (optional note only)
- Plan 001 mise migration details (preserve current version-manager behavior)
- Secrets redesign (plan 003)
- Atuin/direnv (plan 005)
- Deleting `iterm/` or `vim/` (plan 004)
- Changing bash configs except if they source zsh pieces (they should not)

## Git workflow

- Branch: `advisor/002-modularize-zsh-drop-omz`
- Prefer 2–3 commits: (1) extract modules without behavior change, (2) swap history-substring off OMZ, (3) remove OMZ from install/doctor/docs
- Do NOT push/PR unless asked

## Target layout

```text
.zshrc                      # orchestrator only (~40–80 lines)
zsh/
  path.zsh                  # path_add, PATH assembly, tool env paths
  options.zsh               # setopt, hist, editor/vi mode, keybinds baseline
  theme.zsh                 # git prompt + source chetmancini or inline PROMPT
  aliases.zsh
  git.zsh                   # git aliases + cpbranch/cpmsg/worktree helpers
  functions.zsh             # generic helpers (take, weather, yazi y(), etc.)
  platform.zsh              # sources mac_specific.sh / linux_specific.sh
  secrets.zsh               # api_keys + 1password stubs (source only)
  tools/
    fzf.zsh
    zoxide.zsh
    mise.zsh                # or version-managers.zsh
    completions.zsh         # fpath + compinit
  plugins.zsh               # autosuggestions, syntax-highlighting, history-substring LAST pieces ordered carefully
  fun.zsh                   # cmatrix TMOUT, optional toys — keep isolated
chetmancini.zsh-theme       # may remain at root and be sourced from theme.zsh
```

Exact split may vary ±1 file; **do not** create 30 tiny files. Cap ~10–14 sourced files.

## Steps

### Step 1: Drift check + capture behavior baseline

```bash
git diff --stat a52b4b5..HEAD -- .zshrc install.sh bin/doctor Brewfile
wc -l .zshrc
# Baseline aliases sample
zsh -ic 'alias gs; alias ll; echo DOTFILES=$DOTFILES_DIR' 2>/dev/null | head -20
```

Note `DOTFILES_DIR` resolution must keep working when `.zshrc` is symlinked from `~/.zshrc`.

**Verify**: current `.zshrc` still parses: `zsh -n .zshrc`.

### Step 2: Add `zsh/` modules by move-only (no logic change)

1. Create `zsh/` directory.
2. Cut sections from `.zshrc` into modules listed above **without** editing logic.
3. Replace `.zshrc` body with:

```zsh
# Resolve the repo root from this file so the config works outside ~/dotfiles.
typeset -g DOTFILES_DIR="${${(%):-%N}:A:h}"

_zsh_modules=(
  options
  path
  platform
  theme
  aliases
  git
  functions
  secrets
  tools/fzf
  tools/zoxide
  tools/mise
  tools/completions
  fun
  plugins
)

for _m in ${_zsh_modules[@]}; do
  [[ -r "$DOTFILES_DIR/zsh/${_m}.zsh" ]] && source "$DOTFILES_DIR/zsh/${_m}.zsh"
done
unset _m _zsh_modules
```

Adjust names to match files you create. **Order constraints** (load-bearing):

1. `options` / colors / vi mode before keybinds that need them
2. `path` before tools that call `command -v`
3. `theme` after git prompt helpers exist (define `git_prompt_info` before PROMPT)
4. `secrets` after PATH (so `op` can be found if used later)
5. `completions` / `compinit` after all `fpath` mutations
6. **`plugins` last** — autosuggestions + syntax-highlighting after all `zle`/`bindkey`

4. Keep `DOTFILES_DIR` only in `.zshrc`; modules use `$DOTFILES_DIR`.

**Verify**:

```bash
zsh -n .zshrc
for f in zsh/**/*.zsh(N) zsh/*.zsh(N); do zsh -n "$f" || exit 1; done
# If glob fails in bash, use: find zsh -name '*.zsh' -print0 | xargs -0 -n1 zsh -n
make zsh-check
```

Interactive:

```bash
zsh -ic 'alias gs; type y; echo PROMPT_set=${+PROMPT}' 2>/dev/null | head -20
```

Expected: `gs` is git status alias; `y` is yazi function; prompt non-empty.

### Step 3: Replace OMZ history-substring-search

**Preferred**: Homebrew formula if present:

```bash
brew search zsh-history-substring-search
# or
brew info zsh-history-substring-search
```

If formula exists, add to `Brewfile` next to the other zsh plugins and source from
`/opt/homebrew/share/...` (Darwin) with a Linux fallback path if needed
(`/home/linuxbrew/.linuxbrew/share/...` or distro path).

**Fallback**: copy **only** `history-substring-search.zsh` (and license if required)
into `zsh/vendor/history-substring-search.zsh` from upstream
https://github.com/zsh-users/zsh-history-substring-search — single file vendor,
not full OMZ.

Wire in `zsh/plugins.zsh` or `options.zsh` keybinds (existing `^P`/`^N` bindings
in current `.zshrc` must keep working).

Remove:

```zsh
export ZSH="$DOTFILES_DIR/oh-my-zsh"
# and any source of $ZSH/plugins/...
```

**Verify**:

```bash
rg -n 'oh-my-zsh|export ZSH=' .zshrc zsh/ || echo 'no omz refs in shell'
zsh -ic 'bindkey | grep -i history' 2>/dev/null | head -10
```

### Step 4: Theme without OMZ custom/themes

- Source `"$DOTFILES_DIR/chetmancini.zsh-theme"` from `zsh/theme.zsh` (or merge).
- Remove install-time symlink into `oh-my-zsh/custom/themes/`.
- Keep `git_prompt_info` / precmd hook with the theme (currently in `.zshrc` top).

**Verify**: `zsh -ic 'print -P $PROMPT' 2>/dev/null | head -5` shows λ-style prompt
or at least non-empty prompt with path.

### Step 5: Strip OMZ from `install.sh` and `doctor`

`install.sh`:

- Remove `SKIP_OH_MY_ZSH` flag **or** keep flag as no-op with deprecation message
  for one release (prefer remove from help + `install_oh_my_zsh` call).
- Delete `install_oh_my_zsh` function body that clones OMZ; if theme install was
  only that symlink, delete it.
- Ensure main still runs symlink install, brew, api keys, TPM as before.

`bin/doctor`:

- Remove `check_path_exists "Oh My Zsh checkout"`.
- Remove theme check under `oh-my-zsh/custom/themes/`.
- Add checks:
  - `$DOTFILES_DIR/zsh` directory exists
  - `$DOTFILES_DIR/chetmancini.zsh-theme` exists (or new path)
  - optional: each required module file exists

**Verify**:

```bash
rg -n 'oh-my-zsh|oh_my_zsh|Oh My Zsh' install.sh bin/doctor || echo 'clean'
./install.sh --plan --skip-brew --skip-api-keys 2>&1 | head -80
# Should not mention cloning oh-my-zsh
bin/doctor --skip-tools
```

### Step 6: Makefile + gitignore

- Update `ZSH_FILES` in `Makefile` to include `zsh/**/*.zsh` or an explicit list
  (explicit list is safer for `zsh -n`).
- `.gitignore`: you may leave `oh-my-zsh` ignored so old clones don’t get
  committed; add a one-line comment `# legacy clone path; no longer installed`.

**Verify**: `make check` exit 0.

### Step 7: Docs minimal update

- README / CLAUDE: shell loads modules from `zsh/`; no oh-my-zsh dependency.
- Do not rewrite all docs (plan 008).

**Verify**: `rg -n 'oh-my-zsh' README.md CLAUDE.md` → only historical notes or none.

### Step 8: Optional cleanup note (do not force-delete)

In commit message or `docs/` one-liner: local `~/dotfiles/oh-my-zsh` directories can
be removed by the operator with `rm -rf ~/dotfiles/oh-my-zsh` after confirming
shell works. **Executor does not delete** the operator’s clone automatically.

## Test plan

- `make check` (format, shellcheck on bash, zsh -n)
- `bin/doctor --skip-tools`
- Interactive checklist (executor or operator):
  - [ ] Prompt shows λ and git branch in a repo
  - [ ] `gs`, `ll`, `y` work
  - [ ] Vi mode ESC changes cursor
  - [ ] `^P` / `^N` history substring if plugin loaded
  - [ ] fzf `Ctrl-T` if fzf installed
  - [ ] `cd` uses zoxide if installed
  - [ ] Syntax highlighting still colors commands

No automated unit tests required.

## Done criteria

- [ ] `.zshrc` is a thin orchestrator (< ~100 lines) sourcing `zsh/**/*.zsh`
- [ ] No runtime dependency on `oh-my-zsh/` tree
- [ ] history-substring-search works via brew or `zsh/vendor/`
- [ ] `install.sh` does not clone oh-my-zsh
- [ ] `bin/doctor` does not require oh-my-zsh checkout
- [ ] `make check` exits 0
- [ ] Behavior baseline aliases/prompt still work in interactive smoke
- [ ] Scope respected; `plans/README.md` 002 → DONE

## STOP conditions

- Moving code breaks `DOTFILES_DIR` when `~/.zshrc` is a symlink (prompt/path
  empty) and two fix attempts fail
- Homebrew has no history-substring formula **and** vendoring is blocked by
  licensing uncertainty — stop and ask operator
- `make check` fails on shellcheck for reasons requiring wide rewrites of
  unrelated `bin/*` scripts
- Plan 001 left half-migrated nvm **and** mise in conflicting order and
  behavior is unclear — stop and align with 001 first

## Maintenance notes

- New aliases go in `zsh/aliases.zsh` or `zsh/git.zsh`, not `.zshrc`
- New tools: add `zsh/tools/<name>.zsh` and one line in the orchestrator list
- Plugins that wrap ZLE must load in `plugins.zsh` **after** custom widgets
- Reviewers: watch source order and “syntax-highlighting must be last”
- Follow-ups: plan 005 (atuin/direnv modules), plan 004 (prune OMZ docs/install flags residue)
