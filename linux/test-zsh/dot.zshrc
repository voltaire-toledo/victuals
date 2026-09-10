# ╔══════════════════════════════════════════════════════════════╗
# ║  FEDORA · ZSHRC · TUI-FIRST · MINIMAL · FAST               ║
# ║  System: Fedora, i5-11th, 8GB RAM | Term: Kitty / Ptyxis   ║
# ╚══════════════════════════════════════════════════════════════╝

# ── 0. EARLY EXIT (non-interactive) ────────────────────────────
[[ $- != *i* ]] && return

# ── 1. PATH (dedup, existence-checked, set once) ────────────────
# All PATH manipulation is done here, before anything else,
# so downstream tools always see the correct binaries.
path_prepend() {
  [[ -d "$1" ]] || return
  [[ ":$PATH:" == *":$1:"* ]] && return
  PATH="$1:$PATH"
}
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.local/share/flatpak/exports/bin"
path_prepend "$HOME/.opencode/bin"
path_prepend "$HOME/.clispot/bin"
export PATH

# ── 2. CORE ENVIRONMENT ─────────────────────────────────────────
# Single source of truth for editor, pager, and locale.
export EDITOR=micro
export VISUAL=micro
export PAGER='bat --paging=always'

# ── 3. HISTORY ──────────────────────────────────────────────────
# Extended, shared, deduped history — no performance cost.
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=20000
export SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS   # keep only the latest copy of duplicates
setopt HIST_REDUCE_BLANKS     # strip superfluous whitespace
setopt HIST_VERIFY            # expand before executing !-style commands
setopt SHARE_HISTORY          # sync across all open shells
setopt EXTENDED_HISTORY       # record timestamps
setopt CHECK_JOBS             # warn before exiting with background jobs

# ── 4. ZSH COMPLETION (lightweight, no framework) ───────────────
# Native zsh completion engine — fast, no third-party overhead.
autoload -Uz compinit
# Regenerate .zcompdump at most once per day to keep startup fast.
if [[ -n "${ZDOTDIR:-$HOME}/.zcompdump"(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'   # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ── 5. ALIASES: EDITORS ─────────────────────────────────────────
alias vi='micro'
alias vim='micro'
alias nano='micro'

# ── 6. ALIASES: MODERN CLI REPLACEMENTS ─────────────────────────
# eza — replaces ls with icons, git-awareness, and directory grouping.
if command -v eza &>/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lh --git --icons --group-directories-first'
  alias la='eza -lha --git --icons --group-directories-first'
  alias lt='eza --tree --icons --level=2'
  alias tree='eza --tree --icons'
fi

# bat — plain output for pipes; paging only when needed.
command -v bat  &>/dev/null && alias cat='bat --plain --paging=never'

# rg, fd, btop, trash — safe drop-ins.
command -v rg    &>/dev/null && alias rg='rg --smart-case'
command -v fd    &>/dev/null && alias fd='fd --hidden --follow --exclude .git'
command -v btop  &>/dev/null && alias top='btop'
command -v trash &>/dev/null && alias del='trash -v'

# ── 7. ALIASES: SAFER DEFAULTS ──────────────────────────────────
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -I --preserve-root'
alias mkdir='mkdir -p'

# ── 8. ALIASES: NAVIGATION ──────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias home='cd ~'
alias downloads='cd ~/Downloads'

# ── 9. ALIASES: GIT ─────────────────────────────────────────────
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'

# ── 10. ALIASES: FEDORA DNF ─────────────────────────────────────
alias update='sudo dnf upgrade --refresh'
alias install='sudo dnf install'
alias remove='sudo dnf remove'
alias searchpkg='dnf search'
alias clean='sudo dnf autoremove'

# ── 11. ALIASES: SYSTEM MONITORING ──────────────────────────────
alias cpu='btop'
alias mem='free -h'
alias disk='df -h'
alias ports='ss -tulnp'

# ── 12. ALIASES: PYTHON ─────────────────────────────────────────
alias venv='uv venv --seed'
alias activate='source .venv/bin/activate'

# ── 13. ALIASES: TOOLS & ENTERTAINMENT ──────────────────────────
alias postman='posting'
alias monkeytype='smassh'
alias anime='ani-cli'
alias music='rmpc'
addyt() {
  rmpc addyt "$*"
}
alias files='spf'
syt() {
  [[ -z "$*" ]] && echo "Provide a search query" && return 1
  rmpc searchyt --interactive "$*"
}


# ── 14. COLORED MAN PAGES ───────────────────────────────────────
# Uses LESS_TERMCAP vars for color in man; no extra deps.
export LESS_TERMCAP_mb=$'\E[1;31m'
export LESS_TERMCAP_md=$'\E[1;36m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[1;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[1;32m'

# ── 15. ZOXIDE (smart cd) ───────────────────────────────────────
# eval kept — it's zoxide's only supported init method and is fast.
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# ── 16. FZF — fuzzy finder with fd + bat previews ───────────────
# All FZF config is gated behind a single command check.
if command -v fzf &>/dev/null; then
  # fd as the backend — respects .gitignore, fast.
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

  # Minimal GNOME-style palette (dark surface, accent blue/red).
  export FZF_DEFAULT_OPTS="
    --height=50% --layout=reverse --border=rounded
    --preview 'bat --color=always --style=numbers {}'
    --preview-window=right:55%:wrap
    --bind 'ctrl-/:toggle-preview'
    --color=bg+:#303446,bg:#1e1e2e,spinner:#89b4fa,hl:#585b70
    --color=fg:#cdd6f4,header:#585b70,info:#89b4fa,pointer:#f38ba8
    --color=marker:#f38ba8,fg+:#cdd6f4,prompt:#89b4fa,hl+:#89b4fa"

  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers {}'"
  export FZF_ALT_C_OPTS="--preview 'eza --tree --icons --color=always {}'"

  # Source shell keybindings: Ctrl+T (files), Ctrl+R (history), Alt+C (cd).
  [[ -f /usr/share/fzf/shell/key-bindings.zsh ]] && \
    source /usr/share/fzf/shell/key-bindings.zsh

  # Ctrl+F — fuzzy cd into any directory.
 # Directories to always exclude
 _fcd_excludes=(
   .git .venv venv env .env node_modules __pycache__
   .cache .npm .cargo .rustup .pyenv .rbenv .nvm
   dist build out target .next .nuxt .svelte-kit
   vendor bower_components .terraform .tox
   site-packages dist-packages eggs
   .DS_Store Thumbs.db
   "*.egg-info"
 )

 fcd() {
   local exclude_args=()
   for pattern in "${_fcd_excludes[@]}"; do
     exclude_args+=(--exclude "$pattern")
   done

   local dir
   dir=$(
     fd --type d --hidden --follow \
       --max-depth 6 \
       "${exclude_args[@]}" \
       --color always \
     | fzf \
         --ansi \
         --preview 'eza --tree --icons --color=always --level=2 {}' \
         --preview-window 'right:45%:wrap' \
         --prompt '  ' \
         --pointer '▶' \
         --height '80%' \
         --border rounded \
         --header ' Jump to directory' \
         --bind 'ctrl-/:toggle-preview' \
         --bind 'ctrl-u:preview-page-up' \
         --bind 'ctrl-d:preview-page-down'
   ) && cd "$dir"
 }

 bindkey -s '^F' 'fcd\n'

  # Ctrl+D — fuzzy open file in micro.
  fv() {
    local file
    file=$(fzf --preview 'bat --color=always --style=numbers {}') \
      && micro "$file"
  }
  bindkey -s '^D' 'fv\n'

  # fzf + ripgrep — search file contents, jump to match in micro.
  frg() {
    local result file line
    result=$(rg --color=always --line-number --smart-case "${1:-.}" \
      | fzf --ansi --delimiter=: \
            --preview 'bat --color=always --style=numbers --highlight-line {2} {1}' \
            --preview-window='right:55%:+{2}+3/3')
    [[ -z "$result" ]] && return
    file=${result%%:*}
    line=${${result#*:}%%:*}
    micro +"$line" "$file"
  }
fi

# ── 17. YAZI — file manager with cwd-on-exit ────────────────────
# y() wraps yazi so the shell follows its last directory.
# Ctrl+Y opens yazi.
y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")" || return
  command yazi "$@" --cwd-file="$tmp"
  cwd="$(<"$tmp" 2>/dev/null)"
  [[ -n "$cwd" && -d "$cwd" && "$cwd" != "$PWD" ]] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}
bindkey -s '^Y' 'y\n'
alias yd='yazi /run/media/eren'

# ── 18. TMUX ────────────────────────────────────────────────────
# Only loaded if tmux exists and we're not already inside a session
# or in a GUI editor embedding a terminal.
if command -v tmux &>/dev/null; then
  alias ta='tmux attach-session -t'
  alias tn='tmux new-session -s'
  alias tl='tmux list-sessions'
  alias tk='tmux kill-session -t'
  alias td='tmux detach'

  # fzf-powered session switcher.
  ts() {
    local session
    session=$(tmux list-sessions -F '#S' \
      | fzf --prompt='Switch session: ' --height=40% --layout=reverse --border=rounded) \
      && tmux switch-client -t "$session"
  }
fi

# ── 19. MEDIA & DOWNLOAD TOOLS ──────────────────────────────────
if command -v mpv &>/dev/null; then
  alias play='mpv'
  alias playbg='mpv --no-video'
  ytplay() {
    mpv --ytdl-format="bv*+ba/b" \
        --cache=yes --cache-secs=30 \
        --demuxer-max-bytes=500M \
        --demuxer-max-back-bytes=100M \
        "$@"
  }
fi

command -v axel   &>/dev/null && dln()  { axel -n 10 -a -o "$HOME/Downloads" "$@"; }
command -v aria2c &>/dev/null && dl()   { aria2c -x 10 -s 10 -c --dir="$HOME/Downloads" "$@"; }

if command -v yt-dlp &>/dev/null; then
  ytdl() {
    yt-dlp -f "bv*+ba/b" --merge-output-format mp4 --embed-thumbnail \
      -o "$HOME/Downloads/Video/%(title)s.%(ext)s" "$@"
  }
  ytmp3() {
    yt-dlp -f "bestaudio" --extract-audio --audio-format mp3 \
      -o "$HOME/Downloads/Audio/%(title)s.%(ext)s" "$@"
  }
fi


# Youtube search
ytsearch() {
  local flag="$1"
  local query

  printf "Search YouTube (q to quit): "
  read -r query
  [[ "$query" == "q" || -z "$query" ]] && return 1

  local selected
  selected=$(yt-dlp "ytsearch10:${query}" \
    --print "%(id)s|||%(title)s|||%(duration_string)s|||%(uploader)s|||%(view_count)s" \
    --flat-playlist \
    --no-warnings 2>/dev/null \
    | awk -F'|||' '{printf "%-13s %s\n", $1, $2"  |  "$3"  |  "$4"  |  views: "$5}' \
    | fzf \
        --prompt="▶  Select: " \
        --height=80% \
        --reverse \
        --delimiter=" " \
        --preview='
          id=$(echo {1})
          yt-dlp "https://www.youtube.com/watch?v=$id" \
            --print "Title     : %(title)s\nUploader  : %(uploader)s\nDuration  : %(duration_string)s\nViews     : %(view_count)s\nLikes     : %(like_count)s\nUpload    : %(upload_date>%Y-%m-%d)s\nURL       : https://youtu.be/%(id)s" \
            --flat-playlist --no-warnings 2>/dev/null
        ' \
        --preview-window=right:45%:wrap)

  [[ -z "$selected" ]] && return 1

  local id
  id=$(echo "$selected" | awk '{print $1}')

  case "$flag" in
    -p)  mpv "https://www.youtube.com/playlist?list=$id" ;;
    -a)  mpv --no-video "https://www.youtube.com/watch?v=$id" ;;
    -pa) mpv --no-video "https://www.youtube.com/playlist?list=$id" ;;
    *)   mpv "https://www.youtube.com/watch?v=$id" ;;
  esac
}

# Audio-only variant
ytsearchmp3() {
  ytsearch -a "$@"
}

# ── 20. CONDA — true lazy load (zero startup cost) ──────────────
# The conda function shadow replaces itself on first call, then
# forwards the original arguments. No eval at startup, no $PATH
# pollution, no __conda_setup, no conda-related errors on login.
conda() {
  unfunction conda  # remove this stub
  local _conda_bin="$HOME/miniconda3/bin/conda"
  if [[ ! -x "$_conda_bin" ]]; then
    echo "conda: miniconda3 not found at $_conda_bin" >&2
    return 1
  fi
  eval "$("$_conda_bin" shell.zsh hook)"
  conda "$@"   # now calls the real conda
}

# ── 21. ATUIN — shell history sync (replaces Ctrl+R) ────────────
# Loaded last so it can override keybindings set above if present.
command -v atuin &>/dev/null && eval "$(atuin init zsh)"

# ── 22. STARSHIP PROMPT ─────────────────────────────────────────
# Must be the very last eval — other tools (zoxide, atuin) may
# emit prompt-related code that starship needs to wrap.
command -v starship &>/dev/null && eval "$(starship init zsh)"

# ── 23. FASTFETCH (optional splash) ─────────────────────────────
# Shown only in interactive, non-editor terminals.
if [[ -z "$VSCODE_INJECTION" && "$TERM_PROGRAM" != "vscode" && "$TERM_PROGRAM" != "zed" ]]; then
  command -v fastfetch &>/dev/null && fastfetch
fi

# ╔══════════════════════════════════════════════════════════════╗
# ║  END                                                        ║
# ╚══════════════════════════════════════════════════════════════╝

# Composio CLI
export COMPOSIO_INSTALL_DIR="/home/eren/.composio"
export PATH="$COMPOSIO_INSTALL_DIR:$PATH"
