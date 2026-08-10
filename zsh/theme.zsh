# Git prompt helpers + custom λ theme (chetmancini.zsh-theme).
# Performance: cache git status per-directory with a short TTL to avoid
# forking git on every precmd. 5s is enough to keep the prompt in sync
# for normal editing while cutting repeated work in large repos.
typeset -g GIT_PROMPT_INFO=""
typeset -g _GIT_PROMPT_CACHE_DIR=""
typeset -g _GIT_PROMPT_CACHE_TIME=0
typeset -g _GIT_PROMPT_CACHE_RESULT=""

_update_git_prompt_info() {
  local ref status_text now dir

  # Short TTL cache — same dir within window reuses last result.
  now=${EPOCHSECONDS:-$(date +%s)}
  dir="$PWD"
  if [[ "$dir" == "$_GIT_PROMPT_CACHE_DIR" ]] && (( now - _GIT_PROMPT_CACHE_TIME < 5 )); then
    GIT_PROMPT_INFO="$_GIT_PROMPT_CACHE_RESULT"
    return
  fi

  GIT_PROMPT_INFO=""

  GIT_OPTIONAL_LOCKS=0 command git rev-parse --git-dir >/dev/null 2>&1 || {
    _GIT_PROMPT_CACHE_DIR="$dir"
    _GIT_PROMPT_CACHE_TIME=$now
    _GIT_PROMPT_CACHE_RESULT=""
    return
  }

  ref=$(GIT_OPTIONAL_LOCKS=0 command git symbolic-ref --quiet --short HEAD 2>/dev/null) \
    || ref=$(GIT_OPTIONAL_LOCKS=0 command git describe --tags --exact-match HEAD 2>/dev/null) \
    || ref=$(GIT_OPTIONAL_LOCKS=0 command git rev-parse --short HEAD 2>/dev/null) \
    || {
      _GIT_PROMPT_CACHE_DIR="$dir"
      _GIT_PROMPT_CACHE_TIME=$now
      _GIT_PROMPT_CACHE_RESULT=""
      return
    }

  status_text=$(GIT_OPTIONAL_LOCKS=0 command git status --porcelain --ignore-submodules=dirty 2>/dev/null)

  if [[ -n "$status_text" ]]; then
    GIT_PROMPT_INFO="git:(%{$fg[red]%}${ref:gs/%/%%}%{$reset_color%}%{$fg[blue]%}) %{$fg[yellow]%}✗%{$reset_color%}"
  else
    GIT_PROMPT_INFO="git:(%{$fg[red]%}${ref:gs/%/%%}%{$reset_color%}%{$fg[blue]%})"
  fi

  _GIT_PROMPT_CACHE_DIR="$dir"
  _GIT_PROMPT_CACHE_TIME=$now
  _GIT_PROMPT_CACHE_RESULT="$GIT_PROMPT_INFO"
}

git_prompt_info() {
  echo -n "$GIT_PROMPT_INFO"
}

add-zsh-hook precmd _update_git_prompt_info

[ -f "$DOTFILES_DIR/chetmancini.zsh-theme" ] && source "$DOTFILES_DIR/chetmancini.zsh-theme"
