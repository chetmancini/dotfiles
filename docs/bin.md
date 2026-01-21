# Utility Scripts

> Custom scripts for daily workflows and system management

## Overview

The `bin/` directory contains utility scripts for common tasks: archive extraction, process management, system updates, and more. Scripts are available in `$PATH` via the dotfiles installation.

## Setup

**Directory:** `bin/` (added to PATH)

Scripts use a shared helper library at `bin/lib/helpers.sh` for consistent output formatting.

## Scripts Reference

### Daily Workflow

#### good-morning

Master orchestration script for daily startup tasks.

```bash
good-morning              # Run all daily tasks
good-morning --init       # Generate config file
good-morning --dry-run    # Preview actions
good-morning --verbose    # Detailed output
```

**Runs sequentially:**
1. Disk space health check
2. Software updates (via `update-everything`)
3. Dashboard display

**Config:** `~/.config/good-morning/config`

---

#### dashboard

Display system information at a glance.

```bash
dashboard                 # Show all info
dashboard --dry-run       # Preview API calls
dashboard --no-header     # Skip header
```

**Shows:**
- Weather forecast (via wttr.in)
- Calendar events (via gcalcli)
- GitHub notifications (via gh CLI, with clickable links)

**Config:** `~/.config/good-morning/config`

---

#### update-everything

Comprehensive system and repository updates.

```bash
update-everything           # Run all updates
update-everything --dry-run # Preview actions
update-everything --verbose # Detailed output
```

**Updates:**
- Homebrew (update, upgrade, cleanup)
- macOS software (check only)
- Git repositories in `~/norm`
- Docker (system prune)
- Neovim plugins
- Dotfiles repository

---

### File Operations

#### extract

Universal archive extraction with automatic format detection.

```bash
extract archive.tar.gz              # Extract to current dir
extract archive.zip ~/extracted/    # Extract to specific dir
extract -q file.7z                  # Quiet mode
extract -v file.rar                 # Verbose (default)
```

**Supported formats:**
`.tar.bz2`, `.tar.gz`, `.bz2`, `.rar`, `.gz`, `.tar`, `.tbz2`, `.tgz`, `.zip`, `.Z`, `.7z`

**Dependencies:** tar, bunzip2, unrar, gunzip, unzip, uncompress, 7z

---

#### imgcat

Display images directly in terminal (iTerm2 protocol).

```bash
imgcat screenshot.png                    # Display file
cat image.jpg | imgcat                   # From stdin
curl -s https://example.com/img | imgcat # From URL
```

**Features:**
- Works with iTerm2 and compatible terminals
- Handles tmux compatibility
- Supports reading from stdin

---

#### removeexif

Strip EXIF metadata from JPEG images.

```bash
removeexif photo.jpg      # Single file
removeexif *.jpg          # Multiple files
```

**Dependencies:** jhead

---

### Process Management

#### murder

Aggressive process termination with signal escalation.

```bash
murder 1234         # Kill by PID
murder firefox      # Kill by name
murder :3000        # Kill by port
```

**Signal escalation:**
SIGTERM → SIGINT → SIGHUP → SIGKILL (with delays between each)

**Features:**
- Interactive confirmation for safety
- Finds processes by PID, name, or port number
- Written in Ruby

---

#### running

Display running processes with optional filtering.

```bash
running              # All processes
running node         # Filter by name
running python       # Filter by name
```

**Output:** PID and command, colorized

---

### Network

#### flushdns

Flush DNS cache on macOS.

```bash
flushdns
```

**Runs:**
```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

**Requirements:** sudo privileges, macOS only

---

#### my_ip

Display IP address and network interface information.

```bash
my_ip                    # Default interface (eth0)
my_ip -i wlan0          # Specific interface
my_ip -q                # Quiet mode
```

**Options:**
- `-i interface`: Specify network interface
- `-v`: Verbose mode (default)
- `-q`: Quiet mode
- `-h`: Help

---

### Git Utilities

#### git-rm-gone

Clean up local branches whose remote tracking branch was deleted.

```bash
git-rm-gone
```

**Features:**
- Finds branches marked as "gone" after `git fetch --prune`
- Skips current branch for safety
- Shows before/after listing

**Typical workflow:**
```bash
git fetch --prune
git-rm-gone
```

---

### Formatting

#### prettypath

Format PATH variable for readability.

```bash
prettypath
```

**Output:**
```
/usr/local/bin
/usr/bin
/bin
/usr/sbin
/sbin
```

---

### Examples

#### pyexample.py

Example Python script demonstrating uv script execution.

```bash
./pyexample.py
```

Uses `uv run --script` shebang for automatic dependency management.

---

## Shared Helper Library

`bin/lib/helpers.sh` provides common functions:

| Function | Purpose |
|----------|---------|
| `print_section()` | Section header |
| `print_success()` | Green success message |
| `print_error()` | Red error message |
| `print_info()` | Blue info message |
| `print_link()` | Terminal hyperlink (OSC 8) |
| `run_with_spinner()` | Run with spinner animation |

**Usage in scripts:**
```bash
source "$(dirname "$0")/lib/helpers.sh"

print_section "Starting task"
print_success "Done!"
```

## Configuration

Scripts share a config file at `~/.config/good-morning/config`:

```bash
# Example config
WEATHER_LOCATION="San Francisco"
CALENDAR_DAYS=7
GITHUB_NOTIFICATIONS=true
UPDATE_REPOS_DIR="$HOME/norm"
```

Generate default config:
```bash
good-morning --init
```

## Adding New Scripts

1. Create the script in `bin/`
2. Add shebang line (`#!/bin/bash` or `#!/usr/bin/env ruby`)
3. Make executable: `chmod +x script_name`
4. Source helpers if needed: `source "$(dirname "$0")/lib/helpers.sh"`
5. Add documentation to this file

## Dependencies

Most scripts check for required tools and fail gracefully. Common dependencies:

| Script | Requires |
|--------|----------|
| extract | tar, unzip, 7z, etc. |
| murder | Ruby |
| dashboard | gcalcli, gh |
| imgcat | iTerm2-compatible terminal |
| removeexif | jhead |
| flushdns | macOS |
