# Custom Scripts Documentation

This directory contains custom utility scripts that enhance the command-line experience.

## Scripts Overview

| Script | Language | Purpose |
|--------|----------|---------|
| [`extract`](#extract) | Bash | Archive extraction utility |
| [`imgcat`](#imgcat) | Bash | Display images in terminal |
| [`removeexif`](#removeexif) | Bash | Remove EXIF metadata from images |
| [`flushdns`](#flushdns) | Bash | Flush DNS cache (macOS) |
| [`murder`](#murder) | Ruby | Force-kill processes with escalation |
| [`prettypath`](#prettypath) | Bash | Format PATH variable for readability |
| [`running`](#running) | Bash | Display running processes |
| [`my_ip`](#my_ip) | Bash | Show IP address information |
| [`pyexample.py`](#pyexamplepy) | Python | Example Python script with uv |

## Detailed Documentation

### `extract`

Universal archive extraction utility that handles multiple compression formats.

**Usage:**
```bash
extract [-v | -q] <file> [destination]
```

**Options:**
- `-v`: Verbose mode (default) - shows extraction progress
- `-q`: Quiet mode - minimal output
- `<file>`: Archive file to extract
- `[destination]`: Target directory (default: current directory)

**Supported formats:**
- `.tar.bz2`, `.tar.gz`, `.bz2`, `.rar`, `.gz`, `.tar`, `.tbz2`, `.tgz`, `.zip`, `.Z`, `.7z`

**Dependencies:** tar, bunzip2, unrar, gunzip, unzip, uncompress, 7z

**Example:**
```bash
extract archive.tar.gz ~/extracted/
extract -q file.zip
```

---

### `imgcat`

Display images directly in the terminal using iTerm2's image display protocol.

**Usage:**
```bash
imgcat filename [...]
# or
cat filename | imgcat
```

**Features:**
- Supports multiple image formats
- Works with iTerm2 and compatible terminals
- Can read from files or stdin
- Handles tmux compatibility

**Example:**
```bash
imgcat screenshot.png
curl -s https://example.com/image.jpg | imgcat
```

---

### `removeexif`

Remove EXIF metadata from JPEG images using jhead.

**Usage:**
```bash
removeexif image.jpg
```

**Features:**
- Strips all EXIF data from JPEG files
- Simple wrapper around `jhead -purejpg`

**Dependencies:** jhead

**Example:**
```bash
removeexif *.jpg
```

---

### `flushdns`

Flush the DNS cache on macOS systems.

**Usage:**
```bash
flushdns
```

**Features:**
- Clears system DNS cache
- Restarts mDNSResponder service
- macOS only (Linux support placeholder)

**Requirements:** Administrative privileges (uses sudo)

---

### `murder`

Aggressive process termination utility with signal escalation.

**Usage:**
```bash
murder <pid|name|:port>
```

**Features:**
- Escalating signal termination: SIGTERM → SIGINT → SIGHUP → SIGKILL
- Support for killing by PID, process name, or port
- Interactive confirmation for safety

**Examples:**
```bash
murder 1234          # Kill process by PID
murder firefox       # Kill all firefox processes
murder :3000         # Kill process using port 3000
```

---

### `prettypath`

Format the PATH environment variable for better readability.

**Usage:**
```bash
prettypath
```

**Features:**
- Displays each PATH entry on a separate line
- Removes clutter from long PATH strings

**Example output:**
```
/usr/local/bin
/usr/bin
/bin
```

---

### `running`

Display currently running processes with optional filtering.

**Usage:**
```bash
running [process_name]
```

**Features:**
- Shows PID and command for running processes
- Optional filtering by process name
- Colorized output

**Examples:**
```bash
running              # Show all processes
running chrome       # Show chrome-related processes
```

---

### `my_ip`

Display IP address and network interface information.

**Usage:**
```bash
my_ip [-i interface] [-v | -q] [-h]
```

**Options:**
- `-i interface`: Specify network interface (default: eth0)
- `-v`: Verbose mode (default)
- `-q`: Quiet mode
- `-h`: Show help

**Features:**
- Shows IP address for specified interface
- Displays ISP/peer address for PPP connections
- Cross-platform (Linux focused)

**Examples:**
```bash
my_ip                    # Show eth0 IP
my_ip -i wlan0 -q       # Show wlan0 IP quietly
```

---

### `pyexample.py`

Example Python script demonstrating uv usage for script execution.

**Usage:**
```bash
./pyexample.py
```

**Features:**
- Uses `uv run --script` shebang for dependency management
- Minimal example of modern Python script execution

**Dependencies:** uv

---

## Installation

All scripts are automatically available in your PATH through the dotfiles installation. The `install.sh` script creates symlinks from `~/dotfiles/bin/` to `~/bin/`.

## Contributing

When adding new scripts:

1. Include proper shebang lines
2. Add help/documentation within the script
3. Make scripts executable: `chmod +x script_name`
4. Add documentation to this file
5. Test on both macOS and Linux if applicable

## Dependencies

Most scripts have minimal dependencies and will gracefully fail if requirements aren't met. Check individual script documentation for specific requirements.