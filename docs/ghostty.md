# Ghostty

> Fast, GPU-accelerated terminal emulator with native macOS integration

## Overview

Ghostty is a modern terminal emulator focused on speed and native platform integration. Configured with the TokyoNight theme, semi-transparent background, and quick terminal toggle.

## Setup

**Config directory:** `ghostty/` symlinked to `~/.config/ghostty`

**Dependencies:**
- Ghostty app (install from [ghostty.org](https://ghostty.org/))
- JetBrains Mono Nerd Font (via Brewfile cask fonts)

## Quick Reference

### Keybindings

| Action | Keybinding | Notes |
|--------|------------|-------|
| Quick terminal | `Cmd+\`` | Global hotkey, toggle |
| Screenshot | `Super+f` | Save and open |
| New tab | `Cmd+t` | Default |
| Close tab | `Cmd+w` | Default |
| Split horizontal | `Cmd+d` | Default |
| Split vertical | `Cmd+Shift+d` | Default |

### Special Key Sequences

| Action | Keybinding | Sends |
|--------|------------|-------|
| Shift+Enter | `Shift+Enter` | `ESC` + `Enter` |

## Features

### Theme: TokyoNight

Modern, eye-friendly color scheme with vibrant syntax highlighting colors.

### Transparent Background

90% opacity with 20px blur radius. Works well with:
- Desktop wallpapers
- Other windows behind terminal
- The Catppuccin theme in neovim (also transparent)

### Font: JetBrains Mono NL Nerd Font

Monospace font with:
- Programming ligatures
- Nerd Font icons (for file browsers, status lines)
- Clear distinction between similar characters

### Quick Terminal Toggle

`Cmd+\`` (global) summons a quick terminal from anywhere:
- Works when Ghostty is not focused
- Toggles visibility
- Great for quick commands

### macOS Tabs

Uses native macOS tabs in the titlebar:
- Integrated with window chrome
- Drag to reorder
- Click to switch

### Block Cursor

Non-blinking block cursor for clear visibility. The cursor style hint is disabled for cleaner shell integration.

## Configuration

Full config in `ghostty/config`:

```ini
# Theme
theme = tokyonight

# Transparency
background-opacity = 0.9
background-blur-radius = 20

# Font
font-family = JetBrainsMonoNL Nerd Font

# Cursor
cursor-style = block
cursor-style-blink = false

# Window
macos-titlebar-style = tabs
window-padding-x = 10
window-padding-y = 10
window-padding-balance = true
confirm-close-surface = false

# Keybindings
keybind = global:cmd+grave_accent=toggle_quick_terminal
keybind = super+f=write_screen_file:open
keybind = shift+enter=text:\x1b\r
```

## Key Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `theme` | `tokyonight` | Color scheme |
| `background-opacity` | `0.9` | 90% opaque |
| `background-blur-radius` | `20` | Frosted glass effect |
| `font-family` | `JetBrainsMonoNL Nerd Font` | Coding font with icons |
| `cursor-style` | `block` | Block cursor |
| `cursor-style-blink` | `false` | No blinking |
| `macos-titlebar-style` | `tabs` | Tabs in titlebar |
| `window-padding-x/y` | `10` | Content padding |
| `confirm-close-surface` | `false` | No close confirmation |

## Integrations

### tmux

The transparency works well with tmux. The status bar shows through slightly. Quick terminal toggle works with tmux sessions.

### Neovim

The transparent background in neovim (Catppuccin) combines with Ghostty's transparency for a unified look.

### Shell Integration

The `shell-integration-features = no-cursor` setting prevents conflicts between Ghostty's cursor and shell cursor handling.

## Customization

### Change Theme

```ini
theme = DoomOne
# or
theme = catppuccin-mocha
```

List available themes:
```bash
ls /Applications/Ghostty.app/Contents/Resources/themes/
```

### Adjust Transparency

```ini
# More transparent
background-opacity = 0.8

# Less transparent
background-opacity = 0.95

# Disable blur
background-blur-radius = 0
```

### Change Font

```ini
font-family = Fira Code
font-size = 14
```

### Disable Quick Terminal

Remove or comment out:
```ini
# keybind = global:cmd+grave_accent=toggle_quick_terminal
```

### Add Custom Keybindings

```ini
# Open new window
keybind = cmd+n=new_window

# Increase font size
keybind = cmd+plus=increase_font_size:1
```

## Troubleshooting

### Font icons not showing

Ensure Nerd Font is installed:
```bash
brew install --cask font-jetbrains-mono-nerd-font
```

Restart Ghostty after installing.

### Transparency not working

Transparency requires macOS compositor support. Check:
1. System Settings > Accessibility > Display > Reduce transparency is OFF
2. Restart Ghostty

### Quick terminal not working

The global keybind requires accessibility permissions:
1. System Settings > Privacy & Security > Accessibility
2. Enable Ghostty

### Colors look wrong

Ensure your shell sets `TERM` correctly:
```bash
export TERM=xterm-256color
```

Or let Ghostty handle it (default behavior).
