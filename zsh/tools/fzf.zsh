if command -v fzf &> /dev/null; then
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    eval "$(fzf --zsh)"
  fi

  # Use fd for fzf's file/dir walking: faster and respects .gitignore.
  # Drives Ctrl-T, Alt-C, and **<Tab> completion in addition to the defaults.
  if command -v fd &> /dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  fi
  export FZF_DEFAULT_OPTS='--height 60% --layout=reverse --border'
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range :500 {}'"
  export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always --level=2 {}'"

  # Fuzzy cd into directory
  fcd() {
    local dir
    dir=$(fd --type d . 2>/dev/null | fzf --preview 'eza --all --long --icons {}')
    [ -n "$dir" ] && builtin cd "$dir"
  }

  # Fuzzy kill process
  fkill() {
    local pid
    pid=$(ps aux | sed 1d | fzf --multi --preview 'echo {}' | awk '{print $2}')
    [ -n "$pid" ] && echo "$pid" | xargs kill -${1:-9}
  }

  # Fuzzy git checkout branch (local + remote)
  fbr() {
    local branch
    branch=$(git branch -a --color=always | grep -v HEAD | fzf --ansi --preview 'git log --oneline --graph --color=always {1}' | sed 's/^[* ]*//' | sed 's/remotes\/origin\///')
    [ -n "$branch" ] && git checkout "$branch"
  }

  # Fuzzy git log browser
  flog() {
    git log --oneline --color=always | fzf --ansi --preview 'git show --color=always {1}' | awk '{print $1}' | xargs -I {} git show {}
  }

  # Fuzzy search file contents and open in editor
  fsearch() {
    local selection file line
    selection=$(rg --line-number --no-heading . 2>/dev/null | \
      fzf --delimiter ':' --preview 'bat --color=always --highlight-line {2} {1}')
    [ -z "$selection" ] && return
    file="${selection%%:*}"
    line="${selection#*:}"
    line="${line%%:*}"
    "$EDITOR" "$file" "+$line"
  }
fi
