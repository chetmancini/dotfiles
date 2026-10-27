# Package-manager policy

Each executable has one preferred owner. Installing the same CLI through more
than one manager makes PATH order decide which version runs and makes updates
hard to reason about.

| What it is | Preferred owner | Notes |
|---|---|---|
| Runtimes and standalone developer CLIs | Mise | Node, Python, Bun, pnpm, uv, Ruff, gh, jq, ripgrep, fd, bat, fzf, zoxide, ShellCheck, shfmt, StyLua, RTK. Project configs can override global versions. |
| macOS apps, native tools, and system dependencies | Homebrew | Desktop apps, fonts, shell plugins, native libraries, services, and remaining Brewfile tools. Keep runtime packages when another formula requires them. |
| Remaining intentional JavaScript globals | npm or pnpm | Prefer Mise for published standalone CLIs; retain editable local packages and tools that require their package manager. Project dependencies stay local. |
| Vendor-managed CLIs | Vendor installer | Mise itself uses its official installer. Claude Code stays vendor-managed in this migration; its desktop cask is a separate app. |

`mise/config.toml` is linked to `~/.config/mise/config.toml`. On macOS,
`install.sh` installs its tools after linking config for development and desktop
profiles. Minimal retains its native shell/Git tools without installing Mise.
Arch's native package manifests are unchanged in this migration.

Mise checks for its own updates weekly, with a three-day release delay. Selected
everyday CLIs opt into daily updates with the same delay; build/package tools
and runtimes upgrade only on request. Global Node/Python requests permit patch
updates within their selected minor versions. Pin exact versions in project
configs when needed. Auto-updates never rewrite project configuration.

A vendor updater must not overwrite Mise's versioned installation. Keep a tool
vendor-owned until its updater is disabled or delegates to Mise correctly.


`npm/npmrc` contains public defaults only. The installer copies it to `~/.npmrc`
on first install and preserves existing local configuration. Older links into
the checkout are converted to regular files while preserving their contents.
Private registry settings and login tokens belong in the local `~/.npmrc` and
must never be added to the public template.

The machine-wide npm prefix is `~/.npm-global`; its bin directory is added to
PATH. The pnpm global bin comes from `pnpm bin --global` and is expected at
`~/Library/pnpm/bin` on a standard macOS setup.

## Commands

```bash
package-sync             # verify npm and pnpm global-store setup
package-sync --update    # update global npm and pnpm packages
package-sync --npm       # check only npm
package-sync --update --pnpm

mise outdated --global  # inspect available global tool upgrades
mise upgrade --global   # update within configured requests
update-everything        # updates mise tools and remaining npm/pnpm globals
brew-sync                # permits policy-owned tools outside Homebrew
doctor                   # reports PATH or installer-policy issues
```

`brew-sync` consults `bin/lib/package-policy.sh`. When a listed formula or
cask is absent but the preferred external command is available, it reports the
tool as healthy instead of asking Homebrew to install a duplicate. Add a record
there before moving a tool between package managers.

`RUN_MISE_UPGRADE=false` in `~/.config/good-morning/config` disables the Mise
step in `update-everything`; npm/pnpm retain their existing independent switches.
The Mise step uses `--global` even when invoked from a project.

During migration, install and verify the Mise executable before removing its
Homebrew copy. Check `brew uses --installed <formula>` first; keep required
formulae and never use `--ignore-dependencies`. `brew-sync --add` and `--update`
exclude policy-supplied tools rather than restoring duplicate declarations.
Keep npm/pnpm PATH support while any intentional globals still need it.
