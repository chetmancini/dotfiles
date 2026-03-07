# SSH Prompt Indicator Options

The theme currently uses **Option 1** (hostname in yellow, shown only in SSH sessions).

## Option 1 (active): Minimal hostname

Shows the machine hostname in yellow only when in an SSH session. Silent locally.

```zsh
_ssh_indicator() {
  if [[ -n "$SSH_TTY" || -n "$SSH_CONNECTION" ]]; then
    echo "%{$fg_bold[yellow]%}%m%{$reset_color%} "
  fi
}
PROMPT='%{$fg_bold[red]%}λ $(_ssh_indicator)...'
```

Local: `λ <dir> git:(...)`
SSH:   `λ hostname <dir> git:(...)`

---

## Option 2: Colored SSH badge

More visually aggressive. Shows a red `SSH` badge + yellow hostname. Hard to miss — good for preventing accidental destructive commands on remote hosts.

```zsh
_ssh_indicator() {
  if [[ -n "$SSH_TTY" || -n "$SSH_CONNECTION" ]]; then
    echo "%{$bg[red]$fg_bold[white]%} SSH %{$reset_color%} %{$fg_bold[yellow]%}%m%{$reset_color%} "
  fi
}
```

SSH: `λ [SSH] hostname <dir> git:(...)`

---

## Option 3: Always show host, styled by context

Useful when working across many machines and you want constant context. The hostname is dim locally and bold+yellow over SSH.

```zsh
_ssh_indicator() {
  if [[ -n "$SSH_TTY" || -n "$SSH_CONNECTION" ]]; then
    echo "%{$fg_bold[yellow]%}%m%{$reset_color%} "
  else
    echo "%{$fg[white]%}%m%{$reset_color%} "
  fi
}
```

Local: `λ hostname <dir> git:(...)` (muted white)
SSH:   `λ hostname <dir> git:(...)` (bold yellow)
