# Package-manager policy

Each executable has one preferred owner. Installing the same CLI through more
than one manager makes PATH order decide which version runs and makes updates
hard to reason about.

| What it is | Preferred owner | Notes |
|---|---|---|
| Node and Python runtimes | Mise | Project `mise.toml` files can override the global versions. Do not install runtime duplicates with Homebrew. |
| macOS apps, native tools, and system dependencies | Homebrew | This includes Mise itself, pnpm, Bun, uv, and the packages in `Brewfile`. |
| JavaScript CLIs that are intentionally global | npm or pnpm | Keep the runtime in Mise. Use the manager the tool or its team specifies. Project dependencies stay local to the project. |
| Vendor-managed CLIs | Vendor installer | Prefer the vendor release channel when it updates itself or ships more reliably than Homebrew. Claude Code is the current example. |

The machine-wide npm prefix is `~/.npm-global`; its bin directory is added to
PATH. The pnpm global bin comes from `pnpm bin --global` and is expected at
`~/Library/pnpm/bin` on a standard macOS setup.

## Commands

```bash
package-sync             # verify npm and pnpm global-store setup
package-sync --update    # update global npm and pnpm packages
package-sync --npm       # check only npm
package-sync --update --pnpm

update-everything        # also updates npm and pnpm globals by default
brew-sync                # permits policy-owned tools outside Homebrew
doctor                   # reports PATH or installer-policy issues
```

`brew-sync` consults `bin/lib/package-policy.sh`. When a listed formula or
cask is absent but the preferred external command is available, it reports the
tool as healthy instead of asking Homebrew to install a duplicate. Add a record
there before moving a tool between package managers.
