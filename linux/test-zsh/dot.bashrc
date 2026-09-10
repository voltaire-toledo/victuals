# =====================================================
# FEDORA 43 - PYTHON DEVELOPER BASHRC (Improved)
# Optimized for Ptyxis + VSCode Terminal
# =====================================================

# Exit if not interactive
[[ $- != *i* ]] && return

# -----------------------------------------------------
# FASTFETCH (Disable inside VSCode)
# -----------------------------------------------------
if [[ -z "$VSCODE_INJECTION" && "$TERM_PROGRAM" != "vscode" ]]; then
  command -v fastfetch &>/dev/null && fastfetch
fi

# -----------------------------------------------------
# HISTORY CONFIG
# -----------------------------------------------------
export HISTSIZE=20000
export HISTFILESIZE=50000
export HISTCONTROL=ignoredups:erasedups
export HISTTIMEFORMAT="%F %T "
shopt -s histappend checkwinsize

# Append safely to PROMPT_COMMAND (prevents clobber by starship/atuin/others)
__append_prompt_command() {
  local cmd="$1"
  if [[ -z "${PROMPT_COMMAND:-}" ]]; then
    PROMPT_COMMAND="$cmd"
  elif [[ "$PROMPT_COMMAND" != *"$cmd"* ]]; then
    PROMPT_COMMAND="$PROMPT_COMMAND; $cmd"
  fi
}
__append_prompt_command "history -a"
__append_prompt_command "history -n"

# -----------------------------------------------------
# EDITOR
# -----------------------------------------------------
export EDITOR=nvim
export VISUAL=nvim
alias vi='nvim'
alias vim='nvim'

# -----------------------------------------------------
# MODERN CLI REPLACEMENTS (safer)
# -----------------------------------------------------
command -v lsd &>/dev/null && alias ls='lsd'
alias ll='lsd -l'
alias la='lsd -a'
alias lt='lsd --tree'

# Keep cat/grep/rm behaving normally in scripts; provide modern alternatives
command -v bat &>/dev/null && alias cat='bat --plain --paging=never'
command -v rg  &>/dev/null && alias rg='rg --smart-case'
command -v trash &>/dev/null && alias del='trash -v'   # use `del` instead of overriding rm
command -v btop &>/dev/null && alias top='btop'

# -----------------------------------------------------
# SAFER DEFAULTS
# -----------------------------------------------------
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -I --preserve-root'  # safer rm (keeps rm as rm)
alias mkdir='mkdir -p'

# -----------------------------------------------------
# NAVIGATION
# -----------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias home='cd ~'
alias downloads='cd ~/Downloads'

# Zoxide
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"

# -----------------------------------------------------
# FZF KEYBINDINGS
# -----------------------------------------------------
command -v fzf &>/dev/null && \
  [[ -f /usr/share/fzf/shell/key-bindings.bash ]] && \
  source /usr/share/fzf/shell/key-bindings.bash

# -----------------------------------------------------
# ATUIN (History Replacement)
# -----------------------------------------------------
command -v atuin &>/dev/null && eval "$(atuin init bash)"

# -----------------------------------------------------
# STARSHIP PROMPT
# -----------------------------------------------------
command -v starship &>/dev/null && eval "$(starship init bash)"

# -----------------------------------------------------
# GIT PRODUCTIVITY
# -----------------------------------------------------
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'

# Delta pager (DON'T mutate global git config on every shell)
# If you want this globally, run once:
#   git config --global core.pager delta
#   git config --global interactive.diffFilter "delta --color-only"
#   git config --global delta.navigate true
#   git config --global merge.conflictstyle diff3
#   git config --global diff.colorMoved default

alias sh='fzf --preview="bat --color=always {}"'

# -----------------------------------------------------
# PYTHON PRODUCTIVITY
# -----------------------------------------------------
# Avoid aliasing python/pip (can interfere with venv). Prefer:
#   python -m pip ...
alias venv='uv venv --seed'
alias activate='source .venv/bin/activate'

# -----------------------------------------------------
# DOCKER SHORTCUTS (Safer)
# -----------------------------------------------------
alias dps='docker ps'
alias dpa='docker ps -a'
alias dimg='docker images'
alias dexec='docker exec -it'
alias dlog='docker logs -f'

dstop() { docker ps -q | xargs -r docker stop; }
drm()   { docker ps -aq | xargs -r docker rm; }

# -----------------------------------------------------
# SYSTEM MONITORING
# -----------------------------------------------------
alias cpu='btop'
alias mem='free -h'
alias disk='df -h'
alias ports='ss -tulnp'


#------------------------------------------------------
# TOOLS
#------------------------------------------------------

alias postman='posting'
# -----------------------------------------------------
# YAZI - Smart file manager (fixed cwd read)
# -----------------------------------------------------
y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")" || return
  command yazi "$@" --cwd-file="$tmp"
  cwd="$(cat "$tmp" 2>/dev/null)"
  [[ -n "$cwd" && -d "$cwd" && "$cwd" != "$PWD" ]] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

alias yd='yazi /run/media/eren'
alias files='spf'
# -----------------------------------------------------
# ENTERTAINMENT
# -----------------------------------------------------
alias anime='ani-cli'
alias music='rmpc'

# -----------------------------------------------------
# FEDORA DNF SHORTCUTS
# -----------------------------------------------------
alias update='sudo dnf upgrade --refresh'
alias install='sudo dnf install'
alias remove='sudo dnf remove'
alias searchpkg='dnf search'
alias clean='sudo dnf autoremove'

# -----------------------------------------------------
# PATH (avoid duplicates, only if dirs exist)
# -----------------------------------------------------
path_prepend() {
  [[ -d "$1" ]] || return
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.local/share/flatpak/exports/bin"
export PATH

# -----------------------------------------------------
# QUALITY OF LIFE
# -----------------------------------------------------
# Removed: stty -ixon (you said you don't use it)

# Colored man pages
export LESS_TERMCAP_mb=$'\E[1;31m'
export LESS_TERMCAP_md=$'\E[1;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[1;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[1;32m'

# -----------------------------------------------------
# MEDIA & DOWNLOAD TOOLS
# -----------------------------------------------------

# MPV
if command -v mpv &>/dev/null; then
  alias play='mpv'
  alias playbg='mpv --no-video'
  alias ytplay='mpv --ytdl-format="bv*+ba/b" \
  --cache=yes --cache-secs=30 \
  --demuxer-max-bytes=500M \
  --demuxer-max-back-bytes=100M'
fi

# AXEL - Fast HTTP/FTP downloader with many connections
if command -v axel &>/dev/null; then
  dln() { axel -n 10 -a -o "$HOME/Downloads" "$@"; }
fi

# ARIA2 - Versatile downloader (HTTP/FTP/BT/Metalink) with parallel support
if command -v aria2c &>/dev/null; then
  dl() { aria2c -x 10 -s 10 -c --dir="$HOME/Downloads" "$@"; }
fi   

# This is the "nice defaults" YouTube downloader (mp4 + embed thumbnail).
if command -v yt-dlp &>/dev/null; then
  ytdl() {
    yt-dlp "$@" \
      -f "bv*+ba/b" \
      --merge-output-format mp4 \
      --embed-thumbnail \
      -o "$HOME/Downloads/Video/%(title)s.%(ext)s"
  }

  ytmp3() {
    yt-dlp "$@" \
      -f "bestaudio" --extract-audio --audio-format mp3 \
      -o "$HOME/Downloads/Audio/%(title)s.%(ext)s"
  }
fi

# =====================================================
# END
# =====================================================
# >>> conda initialize >>>
# Lazy load conda
conda() {
    eval "$('/home/eren/miniconda3/bin/conda' 'shell.bash' 'hook')"
    conda "$@"
}

export -f conda   
# <<< conda initialize <<<
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# opencode
export PATH=/home/eren/.opencode/bin:$PATH
export PATH="$PATH:/home/eren/.clispot/bin"
. "$HOME/.cargo/env"
