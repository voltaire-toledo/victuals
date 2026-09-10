# ── 0. EARLY EXIT (non-interactive) ────────────────────────────
[[ $- != *i* ]] && return

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
# export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
zstyle ':omz:update' mode reminder  # just remind me to update when it's t

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# ==========================================
# HISTORY CONFIGURATION
# ==========================================
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=20000
export SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS   # Remove older duplicate entries upon saving
setopt HIST_REDUCE_BLANKS     # Remove unnecessary blanks from history
setopt HIST_VERIFY            # Do not execute immediately upon history expansion
setopt SHARE_HISTORY          # Share history between all active sessions
setopt EXTENDED_HISTORY       # Write timestamp to history file
setopt CHECK_JOBS             # Warn before exiting shell if jobs are running

# Completion cache check (regenerate .zcompdump at most once per 24 hours)
autoload -Uz compinit
if [[ -n "${ZDOTDIR:-$HOME}/.zcompdump"(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# ==========================================
# CORE ENVIRONMENT: EDITOR & VISUAL
# ==========================================
if command -v fresh &>/dev/null; then
  export VISUAL="fresh"
elif command -v code-insiders &>/dev/null; then
  export VISUAL="code-insiders --wait"
elif command -v code &>/dev/null; then
  export VISUAL="code --wait"
elif command -v micro &>/dev/null; then
  export VISUAL="micro"
else
  export VISUAL="nano"
fi
export EDITOR="$VISUAL"

# ==========================================
# COLORED MAN PAGES (Native LESS_TERMCAP)
# ==========================================
export LESS_TERMCAP_mb=$'\E[1;31m'      # begin blinking
export LESS_TERMCAP_md=$'\E[1;36m'      # begin bold (cyan)
export LESS_TERMCAP_me=$'\E[0m'         # end mode
export LESS_TERMCAP_se=$'\E[0m'         # end standout
export LESS_TERMCAP_so=$'\E[1;44;33m'   # begin standout (yellow on blue)
export LESS_TERMCAP_ue=$'\E[0m'         # end underline
export LESS_TERMCAP_us=$'\E[1;32m'      # begin underline (green)

# ==========================================
# ALIASES
# ==========================================
## ••• bat (alt cat) •••
alias cat="bat -p --color always"
alias catp="bat --style=plain"
alias catc="bat --plain --color always --nonprintable-notion unicode"

## ••• eza (alt ls) •••
alias ls='eza --icons --group-directories-first --follow-symlinks'
alias ll='eza -lh --icons --git --group-directories-first'
alias l='eza -lha --icons --git --group-directories-first'
alias lt='eza --tree --icons --level=2'
alias tree='eza --tree --icons'

## ••• rg (alt grep) •••
alias grep='rg'

## ••• vscode cli •••
alias c="code"
alias ci="code-insiders"

## ••• PODMAN •••
alias docker="podman"
alias docker-compose="podman compose"

## ••• MISC •••
alias ezsh="fresh ~/.zshrc"

## ••• OpenAI CODEX CLI •••
alias codexy="codex -s danger-full-access -a never"

## ••• Google ANTIGRAVITY CLI •••
alias agyy="agy --dangerously-skip-permissions"
alias pagy="agy --prompt"

## ••• Anthropic CLAUDE CODE •••
alias claudey="claude --dangerously-skip-permissions"
alias pclaude="claude --prompt"

## ••• SEARCH AND FIND BAD SYMLINKS •••
alias badlinks="find . -type l ! -exec test -e {} \; -print"
alias lslinks="find . -type l -ls"

# ==========================================
# ••• fzf •••
# ==========================================
source <(fzf --zsh)

# Make fzf use fd for the default search (respects .gitignore, extremely fast)
export FZF_DEFAULT_COMMAND="fd --type f --hidden --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type d --hidden --exclude .git"

# Default visual layout (Reverse list so it renders bottom-up near your prompt)
export FZF_DEFAULT_OPTS="--layout=reverse --border=rounded --inline-info"

# Ctrl+T: Find files with a real-time 'bat' syntax-highlighted preview
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"

# Alt+C: Find directories with a real-time 'eza' tree preview
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}'"

# Directories to exclude from fcd
_fcd_excludes=(
  .git .venv venv env .env node_modules __pycache__
  .cache .npm .cargo .rustup .pyenv .rbenv .nvm
  dist build out target .next .nuxt .svelte-kit
  vendor bower_components .terraform .tox
  site-packages dist-packages eggs
  .DS_Store Thumbs.db
  "*.egg-info"
)

# Ctrl+F: Fuzzy directory jump
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
        --prompt 'Jump to dir ❯ ' \
        --pointer '▶' \
        --height '80%' \
        --border rounded \
        --bind 'ctrl-/:toggle-preview' \
        --bind 'ctrl-u:preview-page-up' \
        --bind 'ctrl-d:preview-page-down'
  ) && cd "$dir"
}
bindkey -s '^F' 'fcd\n'

# frg: Fuzzy ripgrep -> jump to line in editor
frg() {
  local result file line
  result=$(rg --color=always --line-number --smart-case "${1:-.}" \
    | fzf --ansi --delimiter=: \
          --preview 'bat --color=always --style=numbers --highlight-line {2} {1}' \
          --preview-window='right:55%:+{2}+3/3')
  [[ -z "$result" ]] && return
  file=${result%%:*}
  line=${${result#*:}%%:*}
  ${EDITOR:-nano} +"$line" "$file"
}

# ==========================================
# ••• TMUX HELPER & SESSION SWITCHER •••
# ==========================================
if command -v tmux &>/dev/null; then
  alias ta='tmux attach-session -t'
  alias tn='tmux new-session -s'
  alias tl='tmux list-sessions'
  alias tk='tmux kill-session -t'
  alias td='tmux detach'

  ts() {
    local session
    session=$(tmux list-sessions -F '#S' 2>/dev/null \
      | fzf --prompt='Switch tmux session: ' --height=40% --layout=reverse --border=rounded)
    [[ -z "$session" ]] && return
    if [[ -n "$TMUX" ]]; then
      tmux switch-client -t "$session"
    else
      tmux attach-session -t "$session"
    fi
  }
fi

# ==========================================
# ••• YAZI (TUI file manager + CWD sync) •••
# ==========================================
if command -v yazi &>/dev/null; then
  y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")" || return
    command yazi "$@" --cwd-file="$tmp"
    cwd="$(<"$tmp" 2>/dev/null)"
    [[ -n "$cwd" && -d "$cwd" && "$cwd" != "$PWD" ]] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
  }
  bindkey -s '^Y' 'y\n'
fi

# Path to your Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Select a basic OMZ theme (Starship will completely overwrite the prompt rendering)
ZSH_THEME="re5et"

# Core OMZ Plugins
plugins=(git extract zoxide)

# Local binary execution path extensions
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# User configuration
source $ZSH/oh-my-zsh.sh

# Homebrew support
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"

# Initialize zoxide (Must be initialized after oh-my-zsh to override 'cd')
eval "$(zoxide init zsh --cmd cd)"

# Initialize Starship Prompt Engine
eval "$(starship init zsh)"

# Initialize Mise (Polyglot Toolchain Manager)
eval "$($HOME/.local/bin/mise activate zsh)"

# Added by Antigravity CLI installer
export PATH="/home/me/.local/bin:$PATH"
# Fastfetch
fastfetch

# ==========================================
# CUSTOM FUNCTIONS: GPU-MODEL Management
# ==========================================
function gpu-mode() {
    local current_mode=$(prime-select query)
    echo "Current PRIME Mode: $current_mode"
    
    if [[ "$current_mode" == "intel" ]]; then
        echo "--> Maximum Power Efficiency (Discrete GPU Powered Off)"
    elif [[ "$current_mode" == "on-demand" ]]; then
        echo "--> Balanced Power Usage (Discrete GPU Asleep until needed)"
    elif [[ "$current_mode" == "nvidia" ]]; then
        echo "--> Maximum Performance (High Power Usage)"
    fi

    echo ""
    echo "Select new mode to switch to:"
    echo " (I)ntel Only  - Maximum Power Efficiency"
    echo " (O)n Demand   - Balanced Power Usage"
    echo " (N)vidia Only - Maximum Performance"
    echo " (Q)uit        - Cancel"
    echo -n "Choice [I/O/N/Q]: "
    read -r choice
    
    case "$choice" in
        [iI]*)
            echo "Switching to Intel-only mode..."
            sudo prime-select intel
            ;;
        [oO]*)
            echo "Switching to On-Demand mode..."
            sudo prime-select on-demand
            ;;
        [nN]*)
            echo "Switching to Nvidia-only mode..."
            sudo prime-select nvidia
            ;;
        *)
            echo "Operation cancelled."
            return 0
            ;;
    esac
    
    echo "WARNING: Your system will reboot in 1 minute to apply changes."
    echo "Run 'shutdown -c' to cancel the reboot."
    sudo shutdown -r +1
}

# ==========================================
# KANATA SERVICE MANAGEMENT
# ==========================================
function kanatactl() {
    case "$1" in
        status)
            systemctl --user status kanata
            ;;
        start)
            echo "Starting kanata..."
            systemctl --user start kanata
            ;;
        stop)
            echo "Stopping kanata..."
            systemctl --user stop kanata
            ;;
        restart)
            echo "Restarting kanata..."
            systemctl --user restart kanata
            echo "Kanata restarted!"
            ;;
        *)
            echo "Usage: kanatactl [ status | start | stop | restart ]"
            ;;
    esac
}

# ==========================================
# AUTO LS ON CD
# ==========================================
function auto_ls_on_cd() {
    l 2>/dev/null
    echo
    echo "Directory: $(pwd)"
}
autoload -U add-zsh-hook
add-zsh-hook chpwd auto_ls_on_cd
