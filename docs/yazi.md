# Yazi

> Modern terminal file browser with image preview and git integration

## Overview

Yazi is a fast, async terminal file manager with image preview support, git integration, and vim-style keybindings. Configured with the Gruvbox Dark theme and custom file info display.

## Setup

**Config directory:** `yazi/` symlinked to `~/.config/yazi`

**Dependencies:**
- `yazi` (via Brewfile)
- `ffmpegthumbnailer` (video thumbnails)
- `unar` (archive preview)
- `jq` (JSON preview)
- `poppler` (PDF preview)

**Shell integration:** Add the `y` function to `.zshrc` for cd-on-exit.

## Quick Reference

### Launching Yazi

```bash
y              # Launch with cd-on-exit (from shell function)
yazi           # Launch directly (no cd-on-exit)
yazi /path     # Open specific directory
```

### Navigation

| Action | Keybinding |
|--------|------------|
| Navigate | `h/j/k/l` |
| Go to parent | `h` |
| Enter directory | `l` or `Enter` |
| Go to home | `g` then `h` |
| Go to root | `g` then `/` |
| Search | `/` |

### File Operations

| Action | Keybinding |
|--------|------------|
| Open file | `Enter` |
| Open with... | `o` |
| Rename | `r` |
| Delete | `d` |
| Copy | `y` |
| Cut | `x` |
| Paste | `p` |
| Create file | `a` |
| Create directory | `A` |

### Preview & View

| Action | Keybinding |
|--------|------------|
| QuickLook (macOS) | `Ctrl-p` |
| Toggle hidden files | `.` |
| Refresh | `Ctrl-r` |
| Show EXIF info | Select image, open menu |

### Selection

| Action | Keybinding |
|--------|------------|
| Toggle selection | `Space` |
| Select all | `Ctrl-a` |
| Invert selection | `Ctrl-i` |

## Features

### Theme: Gruvbox Dark

Classic Gruvbox color scheme with file type coloring:
- Directories: Blue
- Images: Yellow
- Videos/Audio: Magenta
- Empty files: Cyan
- Broken symlinks: Red

### Git Integration

The `git.yazi` plugin shows git status on files:
- Modified files marked
- Untracked files indicated
- Repository-aware display

### Custom Linemode

Shows file size and modification time in a smart format:
- Current year: `Jan 15 14:30`
- Previous years: `Jan 15  2024`

### QuickLook Preview

Press `Ctrl-p` to open macOS QuickLook for the selected file. Works with:
- Images
- PDFs
- Documents
- Videos

### 3-Pane Layout

Column ratio `1:3:4`:
- Left: Parent directory
- Center: Current directory (main focus)
- Right: Preview

### Image Previews

Inline image preview in the terminal with:
- Max dimensions: 1200x1000px
- 75% quality
- 30ms delay for smooth scrolling

### Archive Handling

Archives are extracted with `ya pub extract`:
- Supports: zip, tar, 7z, rar, gz, bz2
- Preview archive contents before extraction

## Configuration Files

### yazi.toml

Main configuration:

```toml
[mgr]
ratio = [ 1, 3, 4 ]          # Column widths
sort_by = "alphabetical"      # Sort method
sort_dir_first = true         # Directories at top
show_hidden = true            # Always show dotfiles
linemode = "size_and_mtime"   # Custom display

[preview]
max_width = 1200
max_height = 1000
image_quality = 75
```

### theme.toml

Colors and icons (uses Gruvbox flavor).

### init.lua

Lua plugins and custom functions:

```lua
-- Git status plugin
require("git"):setup()

-- Rounded borders
require("full-border"):setup {
    type = ui.Border.ROUNDED,
}

-- Custom linemode showing size + mtime
function Linemode:size_and_mtime()
    -- Shows intelligent date formatting
end
```

### package.toml

Plugin dependencies:
- `git.yazi` - Git status
- `full-border.yazi` - Border styling
- `gruvbox-dark` - Theme
- `nightfly` - Alternative theme

## Integrations

### Shell (cd-on-exit)

The `y` function in `.zshrc` changes directory when you quit:

```bash
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}
```

### Neovim

Files open in `$EDITOR` (neovim) for editing. The opener config:

```toml
[opener]
edit = [
    { run = '${EDITOR:-vi} "$@"', block = true },
]
```

### Media Players

Videos open in `mpv` with media info available.

## Customization

### Change Theme

Edit `yazi/theme.toml` or use a different flavor:

```toml
# Use nightfly instead
[flavor]
use = "nightfly"
```

### Add Keybindings

Add to `yazi/yazi.toml`:

```toml
[[mgr.prepend_keymap]]
on = "<C-n>"
run = "shell 'nvim' --block"
desc = "Open neovim"
```

### Change Layout Ratio

```toml
[mgr]
ratio = [ 1, 2, 3 ]  # More preview space
# or
ratio = [ 0, 2, 3 ]  # Hide parent column
```

### Customize Linemode

Edit `yazi/init.lua` to change the info displayed:

```lua
function Linemode:custom()
    -- Return string to display
    return self._file:size() or "-"
end
```

## Troubleshooting

### Images not previewing

Install required dependencies:
```bash
brew install ffmpegthumbnailer unar poppler
```

### Git status not showing

Ensure the git plugin is loaded in `init.lua`:
```lua
require("git"):setup()
```

And configured in `yazi.toml`:
```toml
[[plugin.prepend_fetchers]]
id = "git"
name = "*"
run = "git"
```

### QuickLook not working

This is macOS only. The keybinding runs:
```bash
qlmanage -p "$@"
```

### cd-on-exit not working

Ensure you're using the `y` function, not `yazi` directly.
