# tmux

> Terminal multiplexer with vim integration and session management

## Overview

tmux configuration optimized for vim-style navigation with seamless integration between tmux panes and neovim splits. Uses `Ctrl-a` as prefix (like GNU Screen) instead of the default `Ctrl-b`.

## Setup

**Config file:** `.tmux.conf` symlinked to `~/.tmux.conf`

**Dependencies:**
- `tmux` (via Brewfile)
- `fzf` (for session/window switching)

## Quick Reference

### Prefix Key

The prefix is `Ctrl-a` (not the default `Ctrl-b`).

| Notation | Meaning |
|----------|---------|
| `prefix` | Press `Ctrl-a` |
| `prefix + x` | Press `Ctrl-a`, release, then press `x` |

### Essential Keybindings

| Action | Keybinding | Notes |
|--------|------------|-------|
| **Panes** | | |
| Split horizontal | `prefix + \|` | New pane to the right |
| Split vertical | `prefix + _` | New pane below |
| Navigate panes | `Ctrl-h/j/k/l` | Works in vim too |
| Navigate (with prefix) | `prefix + h/j/k/l` | Alternative |
| Previous pane | `Ctrl-\` | Toggle back |
| Resize pane | `prefix + H/J/K/L` | Resize by 5 units |
| **Windows** | | |
| New window | `prefix + c` | In current directory |
| Last window | `prefix + Space` | Toggle between two |
| **Sessions** | | |
| New session | `prefix + N` | Prompts for name |
| Last session | `prefix + Backspace` | Toggle between two |
| Kill session | `prefix + X` | With confirmation |
| FZF sessions | `prefix + S` | Fuzzy find |
| FZF windows | `prefix + W` | Fuzzy find all |
| **Copy Mode** | | |
| Enter copy mode | `prefix + [` | Vi-style navigation |
| Begin selection | `v` | In copy mode |
| Copy to clipboard | `y` | Yanks to system clipboard |
| **Config** | | |
| Reload config | `prefix + r` | Shows confirmation |

## Features

### Seamless Vim Navigation

Uses `vim-tmux-navigator` pattern. `Ctrl-h/j/k/l` works whether you're in:
- A tmux pane (switches panes)
- A neovim split (switches splits)
- fzf (passes through)

The config detects if vim/neovim/fzf is running and routes keys appropriately.

### FZF Session/Window Switching

`prefix + S` opens a popup with all sessions for fuzzy finding:
```
project-a
project-b
dotfiles
```

`prefix + W` shows all windows across all sessions:
```
project-a:1 editor
project-a:2 server
dotfiles:1 config
```

### Git Branch in Status Bar

The right side of the status bar shows:
- Current git branch (magenta)
- Date (yellow)
- Time (white)

### Copy Mode with System Clipboard

In copy mode:
1. Navigate with vim keys (`h/j/k/l`, `/` to search)
2. Press `v` to start selection
3. Press `y` to copy to system clipboard

Works with `pbcopy` on macOS or `xclip` on Linux.

### Session Management

Quick session workflows:
- `prefix + N`: Create new named session
- `prefix + Backspace`: Jump to last session
- `prefix + X`: Kill current session (with confirm)

### Current Path Preservation

New panes and windows open in the current working directory, not the directory where tmux was started.

## Key Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `prefix` | `Ctrl-a` | Screen-style prefix |
| `base-index` | `1` | Windows start at 1 |
| `pane-base-index` | `1` | Panes start at 1 |
| `history-limit` | `50000` | Large scrollback |
| `escape-time` | `0` | No delay for Escape |
| `mouse` | `on` | Mouse support enabled |
| `mode-keys` | `vi` | Vi-style copy mode |
| `focus-events` | `on` | For neovim integration |

## Integrations

### Neovim

Both tmux and neovim are configured with `vim-tmux-navigator`:
- tmux: Smart pane switching that detects vim
- neovim: `nvim/lua/plugins/tmux-navigator.lua`

The same `Ctrl-h/j/k/l` keys work everywhere.

### Ghostty

The transparent background in Ghostty (90% opacity) shows through tmux. The quick terminal toggle (`Cmd+\``) works with tmux sessions.

## Customization

### Change Prefix Key

Edit `.tmux.conf`:
```tmux
set -g prefix C-b  # Back to default
# or
set -g prefix C-Space  # Use Ctrl-Space
```

### Add New Keybindings

```tmux
# Example: bind prefix + g to lazygit
bind g new-window -n "lazygit" "lazygit"
```

### Change Status Bar Colors

```tmux
set -g status-style bg=blue,fg=white
set -g window-status-current-style bg=white,fg=blue,bold
```

## Troubleshooting

### Ctrl-h/j/k/l not working with vim

Ensure both sides are configured:
1. tmux: Check the `is_vim` detection in `.tmux.conf`
2. neovim: Verify `vim-tmux-navigator` plugin is loaded

### Colors look wrong

Ensure terminal supports true color:
```bash
echo $TERM  # Should be xterm-256color or similar
```

The config sets `default-terminal "tmux-256color"` with true color overrides.

### Copy not working

macOS: Ensure `pbcopy` is available
Linux: Install `xclip`
