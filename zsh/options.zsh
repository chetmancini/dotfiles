# Zsh options, history, editor/vi mode, and baseline keybinds.

alias zshconfig="vim $DOTFILES_DIR/.zshrc"

autoload -Uz add-zsh-hook colors
colors
setopt PROMPT_SUBST

COMPLETION_WAITING_DOTS="true"
zstyle ':completion:*' hosts off

##############################
# Variables
##############################
# ZSH Options
DEFAULT_USER="chet"
setopt AUTO_CD
HISTFILESIZE=1000000
HISTSIZE=1000000
SAVEHIST=1000000
# If I type cd and then cd again, only save the last one
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY         # Write immediately and share live across all sessions
setopt HIST_IGNORE_SPACE     # Commands starting with space won't be saved
setopt HIST_SAVE_NO_DUPS
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
# reduce blanks
setopt HIST_REDUCE_BLANKS
# Save the time and how long a command ran
setopt EXTENDED_HISTORY
# Spell check commands!  (Sometimes annoying)
setopt CORRECT
# beeps are annoying
setopt NO_BEEP



##############################
# Editor Settings
##############################
setopt VI
export EDITOR="nvim"
bindkey -v
export KEYTIMEOUT=1  # 10ms delay for multi-char sequences (eliminates ESC lag in vi mode)

# History search:
#   ^R — fallback incremental search; tools/atuin.zsh rebinds to atuin when present
#   ^S — reverse incremental search
#   ^P/^N — history-search here; plugins.zsh upgrades to history-substring-search
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
bindkey '^P' history-search-backward
bindkey '^N' history-search-forward

# Edit command line in $EDITOR (Ctrl-X Ctrl-E)
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Vi mode cursor shape: block for NORMAL, beam for INSERT
function zle-keymap-select {
  if [[ $KEYMAP == vicmd ]] || [[ $1 == 'block' ]]; then
    echo -ne '\e[1 q'  # Block cursor
  elif [[ $KEYMAP == main ]] || [[ $KEYMAP == viins ]] || [[ $1 == 'beam' ]]; then
    echo -ne '\e[5 q'  # Beam cursor
  fi
}
zle -N zle-keymap-select

# Start with beam cursor
function zle-line-init { echo -ne '\e[5 q' }
zle -N zle-line-init

# Reset cursor on command execution
preexec() { echo -ne '\e[5 q' }
