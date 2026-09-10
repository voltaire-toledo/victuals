#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPORT_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-hydration"
REPORT_FILE="$REPORT_DIR/report.txt"
USER_LOCAL_BIN="$HOME/.local/bin"
USER_LOCAL_OPT="$HOME/.local/opt"
USER_APPLICATIONS="$HOME/.local/share/applications"
USER_ICONS="$HOME/.local/share/icons/hicolor/512x512/apps"
REBOOT_REQUIRED=false
SESSION_RESTART_REQUIRED=false
VALIDATION_FAILURES=0

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
LIGHT_BLUE='\033[1;94m'
BRIGHT_CYAN='\033[1;96m'
BRIGHT_GREEN='\033[1;92m'
RESET='\033[0m'

export PATH="$USER_LOCAL_BIN:$PATH"

MODE=full
SELECTIONS_FILE=''
EXPORT_FILE=''
IMPORT_FILE=''
PREVIEW=false
while (($#)); do
  case "$1" in
    full|preview|snap-only|apply|gpu-integrated|gpu-compute)
      MODE="$1"
      ;;
    preview|dry-run|--dry-run|--plan-mode)
      MODE=preview
      PREVIEW=true
      ;;
    --export)
      [[ $# -ge 2 && -n "$2" ]] || { printf '%s\n' 'Usage error: --export requires a file path.' >&2; exit 2; }
      EXPORT_FILE="$2"
      shift
      ;;
    --import)
      [[ $# -ge 2 && -n "$2" ]] || { printf '%s\n' 'Usage error: --import requires a file path.' >&2; exit 2; }
      IMPORT_FILE="$2"
      shift
      ;;
    --help|-h)
      cat <<EOF
Usage: $0 [full|gpu-integrated|gpu-compute|snap-only|apply] [options]

Options:
  --export FILE       Save the selected hydration profile as data-only text.
  --import FILE       Load a profile and skip the interactive category menus.
  --dry-run           Run the complete flow and plan without system changes.
  --plan-mode         Alias for --dry-run.

Examples:
  $0 --dry-run
  $0 --import workstation.hydration --dry-run
  $0 --export workstation.hydration
EOF
      exit 0
      ;;
    *)
      printf 'Usage: %s [full|gpu-integrated|gpu-compute|snap-only|apply] [--export FILE] [--import FILE] [--dry-run|--plan-mode]\n' "$0" >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "$MODE" == preview ]]; then
  PREVIEW=true
fi

if [[ "$PREVIEW" == false ]]; then
  mkdir -p "$REPORT_DIR"
  exec > >(tee "$REPORT_FILE") 2>&1
fi

log() { printf '\n%b==> %s%b\n' "$BLUE" "$*" "$RESET"; }
status() { printf '%b%s%b\n' "$BLUE" "$*" "$RESET"; }
pass() { printf '%bPASS: %s%b\n' "$GREEN" "$*" "$RESET"; }
warn() { printf '%bWARN: %s%b\n' "$YELLOW" "$*" "$RESET" >&2; }
installing() { printf '%bINSTALLING: %s%b\n' "$BLUE" "$*" "$RESET"; }
installed() { pass "Installed: $*"; }
next_step() { printf '%bNEXT STEP: %s%b\n' "$YELLOW" "$*" "$RESET"; }
run_install() {
  local label="$1"
  shift
  installing "$label"
  if "$@"; then
    installed "$label"
  else
    warn "Installation failed: $label"
    return 1
  fi
}

running_snap_names() {
  local snap_name service current proc command_line
  if command -v snap >/dev/null 2>&1; then
    while read -r service _ current _; do
      [[ "$current" == active ]] || continue
      snap_name="${service%%.*}"
      printf '%s\n' "$snap_name"
    done < <(snap services 2>/dev/null | awk 'NR > 1 {print $1, $2, $3, $4}')
  fi

  for proc in /proc/[0-9]*; do
    command_line="$(tr '\0' ' ' < "$proc/cmdline" 2>/dev/null || true)"
    [[ "$command_line" == */snap/* || "$command_line" == *' /snap/'* ]] || continue
    snap_name="$(sed -n 's#.*\/snap\/\([^/]*\)/.*#\1#p' <<<"$command_line")"
    [[ -n "$snap_name" ]] && printf '%s\n' "$snap_name"
  done | sort -u
}

choose_confirmation() {
  local prompt="$1" choice
  choice="$(gum choose --height 2 --header "$prompt" --header.foreground 117 \
    --cursor.foreground 51 --cursor-prefix '● ' Yes No)"
  [[ "$choice" == Yes ]]
}

confirm_running_snaps() {
  local running_snap
  mapfile -t running_snaps < <(running_snap_names)
  ((${#running_snaps[@]})) || return 0

  printf '\n%bRunning Snap applications or services detected:%b\n' "$YELLOW" "$RESET"
  printf '  %s\n' "${running_snaps[@]}"
  choose_confirmation 'Stop and terminate these Snaps before removal?' \
    || fatal 'Snap removal cancelled while Snap applications or services were running'

  for running_snap in "${running_snaps[@]}"; do
    sudo snap stop --disable "$running_snap" 2>/dev/null || true
  done
}

remove_snap() {
  log "Removing Snap and preventing its return"
  confirm_running_snaps
  if command -v snap >/dev/null 2>&1; then
    mapfile -t snaps < <(timeout 30 snap list 2>/dev/null | awk 'NR > 1 {print $1}')
    applications=()
    runtimes=()
    for snap_name in "${snaps[@]}"; do
      case "$snap_name" in
        bare|core*|gnome-*|gtk-common-themes|mesa-*|snapd)
          runtimes+=("$snap_name")
          ;;
        *)
          applications+=("$snap_name")
          ;;
      esac
    done
    # Snap applications must go first; runtimes are removed only after their
    # dependent applications have gone away.
    snaps=("${applications[@]}" "${runtimes[@]}")
    for ((pass=1; pass<=4 && ${#snaps[@]} > 0; pass++)); do
      remaining=()
      # Remove applications first. Base/runtime snaps are retained until no
      # application depends on them, so process the list in reverse order.
      for snap_name in "${snaps[@]}"; do
        if ! sudo timeout 180 snap remove --terminate --purge "$snap_name" 2> >( \
            sed -n '/is not removable: snap .* is being used/!p' >&2); then
          remaining+=("$snap_name")
        fi
      done
      snaps=("${remaining[@]}")
      if ((${#snaps[@]} > 0 && pass < 4)); then
        mapfile -t snaps < <(printf '%s\n' "${snaps[@]}" | tac)
      fi
    done
    if ((${#snaps[@]})); then
      fail "Snap packages could not be removed after retries: ${snaps[*]}"
    fi
  fi
  sudo systemctl disable --now snapd.socket snapd.service snapd.seeded.service 2>/dev/null || true
  sudo apt-get purge -y snapd ubuntu-core-launcher 2>/dev/null || sudo apt-get purge -y snapd
  sudo install -D -m 0644 "$LINUX_DIR/config/apt/no-snap.pref" /etc/apt/preferences.d/no-snap.pref
  if command -v snap >/dev/null 2>&1; then
    fail "snap command remains installed"
  else
    pass "Snap is removed"
  fi
  local snapd_candidate
  snapd_candidate="$(apt-cache policy snapd | sed -n 's/^  Candidate: //p')"
  if [[ "$snapd_candidate" == '(none)' ]]; then
    pass "snapd is pinned against reinstallation"
  else
    fail "snapd still has an install candidate: ${snapd_candidate:-unknown}"
  fi
}
fail() {
  printf '%bFAIL: %s%b\n' "$RED" "$*" "$RESET" >&2
  VALIDATION_FAILURES=$((VALIDATION_FAILURES + 1))
}
fatal() { printf '%bFATAL: %s%b\n' "$RED" "$*" "$RESET" >&2; exit 1; }
trap 'fatal "Hydration stopped at line $LINENO while running: $BASH_COMMAND"' ERR
trap 'printf "\n%bHydration cancelled. No further phases will run.%b\n" "$YELLOW" "$RESET"; exit 130' INT TERM

check_command() {
  local command_name="$1" label="${2:-$1}"
  command -v "$command_name" >/dev/null 2>&1 \
    && pass "$label is installed" \
    || fail "$label is not installed"
}

bootstrap_hydration() {
  local brew_bin tool

  log "Bootstrapping hydration prerequisites"
  run_install "Bootstrap CA certificates" sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates
  run_install "Bootstrap APT metadata" sudo env DEBIAN_FRONTEND=noninteractive apt-get update
  run_install "Bootstrap Git" sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y git
  run_install "Bootstrap curl" sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y curl

  if ! command -v gum >/dev/null 2>&1; then
    installing "Gum menu framework"
    sudo install -d -m 0755 /etc/apt/keyrings
    curl -fsSL --retry 3 https://repo.charm.sh/apt/gpg.key \
      | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *' \
      | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null
    sudo apt-get update
    run_install "Gum menu framework" sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y gum
  fi

  run_install "Bootstrap remaining terminal tools" sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    gdebi-core gnupg flatpak
  run_install "Bootstrap Linuxbrew build tools" \
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential

  run_install "Flathub remote" \
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

  if ! command -v brew >/dev/null 2>&1; then
    installing "Linuxbrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  brew_bin=/home/linuxbrew/.linuxbrew/bin/brew
  [[ -x "$brew_bin" ]] || brew_bin="$(command -v brew || true)"
  [[ -n "$brew_bin" && -x "$brew_bin" ]] || fatal "Linuxbrew installation did not produce brew"
  eval "$("$brew_bin" shellenv)"
  grep -Fxq 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' "$HOME/.profile" 2>/dev/null \
    || printf '\n# Linuxbrew\neval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"\n' >> "$HOME/.profile"

  "$LINUX_DIR/../../install/install-task.sh"
  export PATH="$USER_LOCAL_BIN:$PATH"
  for tool in git gum task flatpak brew gdebi; do
    command -v "$tool" >/dev/null 2>&1 || fatal "Required bootstrap tool is unavailable: $tool"
  done
  pass "Bootstrap prerequisites are ready for the current process and child Tasks"
}

check_service() {
  local service="$1"
  [[ "$(systemctl is-active "$service" 2>/dev/null || true)" == active ]] \
    && pass "$service is active" \
    || fail "$service is not active"
}

install_gnome_extension() {
  local extension_id="$1" uuid="$2" label="$3"
  local shell_version extension_zip
  installing "$label GNOME Shell extension"
  shell_version="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
  [[ -n "$shell_version" ]] || fatal "Could not determine the GNOME Shell version"
  extension_zip="$tmp_dir/${uuid}.zip"

  if ! curl -fL --retry 3 \
      "https://extensions.gnome.org/download-extension/${extension_id}.shell-extension.zip?shell_version=${shell_version}" \
      -o "$extension_zip"; then
    fatal "$label has no downloadable GNOME $shell_version build (extension $extension_id)"
  fi
  gnome-extensions install --force "$extension_zip"
  gnome-extensions enable "$uuid"
  if gnome-extensions list --enabled | grep -Fxq "$uuid"; then
    pass "$label is installed and enabled"
  else
    fail "$label did not reach the enabled state"
  fi
}

choose_one() {
  local prompt="$1" default_index="$2"
  shift 2
  local options=("$@") default
  default="${options[$((default_index - 1))]}"
  local header
  header="$(category_header "$prompt")"
  local choice
  if choice="$(gum choose --height 12 --header "$header" --header.foreground 117 \
    --item.foreground 51 --cursor.foreground 51 --selected.foreground 10 \
    --selected "$default" --cursor-prefix '▸ ' "${options[@]}")"; then
    :
  else
    if [[ "${BACK_ON_CANCEL:-false}" == true && "$?" != 130 ]]; then
      printf '%s' '__BACK__'
    else
      printf '%s' '__CANCEL__'
    fi
    return 0
  fi
  [[ "$choice" == '← Back' ]] && printf '%s' '__BACK__' || printf '%s' "$choice"
}

choose_one_back() { BACK_ON_CANCEL=true choose_one "$@" '← Back'; }

choose_one_back_current() {
  local current="$1" prompt="$2" default_index="$3"
  shift 3
  local options=("$@") index
  for index in "${!options[@]}"; do
    [[ "${options[$index]}" == "$current" ]] && default_index=$((index + 1))
  done
  BACK_ON_CANCEL=true choose_one "$prompt" "$default_index" "${options[@]}" '← Back'
}

terminal_content_width() {
  local width="${COLUMNS:-}"
  [[ "$width" =~ ^[0-9]+$ && "$width" -ge 32 ]] || width="$(tput cols 2>/dev/null || printf '80')"
  [[ "$width" =~ ^[0-9]+$ && "$width" -ge 32 ]] || width=80
  printf '%s' "$((width - 2))"
}

described_header() {
  local title="$1" description="$2" title_line description_line header_text
  printf -v title_line '\033[1;38;5;117m%s\033[0m' "$title"
  printf -v description_line '\033[38;5;250m%s\033[0m' "$description"
  header_text="${title_line}"$'\n'"${description_line}"
  gum style \
    --border rounded \
    --border-foreground 117 \
    --width "$(terminal_content_width)" \
    --padding '0 1' \
    "$header_text"
}

terminal_header() {
  described_header \
    'Terminal Emulator' \
    'System already ships with Ptyxis, which meets most users’ needs, supports themes, but not panes'
}

file_manager_header() {
  described_header 'File Manager' 'Files/Nautilus is retained.'
}

terminal_editor_header() {
  described_header 'Terminal-based Editors' 'Choose one or more editors for your terminal workflow.'
}

hydrator_title() {
  gum style \
    --width "$(terminal_content_width)" \
    --align center \
    --foreground 117 \
    --bold \
    'Hydrator'
}

choose_described_many() {
  local header="$1" selected_values="$2"
  shift 2
  local selections result='' selection option value
  local -a selected_args=()
  for option in "$@"; do
    value="${option##*|}"
    selected "$selected_values" "$value" && selected_args+=(--selected "$option")
  done
  if selections="$(gum choose --no-limit --height 14 --header "$header" \
      --item.foreground 250 --cursor.foreground 51 --selected.foreground 10 --cursor-prefix '▸ ' \
      --selected-prefix '✓ ' --unselected-prefix '○ ' --padding '0 1' \
      --label-delimiter '|' "${selected_args[@]}" "$@")"; then
    :
  else
    if [[ "${BACK_ON_CANCEL:-false}" == true && "$?" != 130 ]]; then
      printf '%s' '__BACK__'
    else
      printf '%s' '__CANCEL__'
    fi
    return 0
  fi
  [[ -z "$selections" ]] && { printf '%s' ''; return; }
  while IFS= read -r selection; do
    [[ "$selection" == '← Back' ]] && { printf '%s' '__BACK__'; return; }
    [[ "$selection" == None ]] && continue
    result+="${selection}|"
  done <<< "$selections"
  printf '%s' "$result"
}

choose_terminal() {
  local options=(
    $'\033[1mPtyxis\033[0m      \033[38;5;250mSystem default; themeable, but no built-in panes.\033[0m|Ptyxis [pre-installed]'
    $'\033[1mGhostty\033[0m     \033[38;5;250mNew hotness. GPU Accelerated. Built with Zed.\033[0m|Ghostty [optional]'
    $'\033[1mAlacritty\033[0m   \033[38;5;250mNo tabs, no panes, no frills. Very fast, but BYO tmux, zellij, herdr, etc.\033[0m|Alacritty [optional]'
    $'\033[1mFoot\033[0m        \033[38;5;250mVery lightweight, very fast even when potato powered, Nothing fancy, not even ligatures.\033[0m|Foot [optional]'
  )
  local header
  header="$(terminal_header)"
  choose_described_many "$header" "$TERMINAL" "${options[@]}"
}

category_header() {
  gum style \
    --border rounded \
    --border-foreground 117 \
    --width "$(terminal_content_width)" \
    --foreground 117 \
    --padding '0 1' \
    --bold \
    "$@"
}

choose_many() {
  local prompt="$1" default_letters="$2" footer="$3"
  shift 3
  local options=("$@") header result="" selections index letter
  local letters=ABCDEFGHIJKLMNOPQRSTUVWXYZ
  default_letters="${default_letters^^}"
  default_letters="${default_letters//[[:space:]]/}"
  if [[ -n "$footer" ]]; then
    header="$(category_header "$prompt" "$footer")"
  else
    header="$(category_header "$prompt")"
  fi
  local -a selected_args=()
  for index in "${!options[@]}"; do
    letter="${letters:index:1}"
    [[ ",$default_letters," == *",$letter,"* ]] && selected_args+=(--selected "${options[$index]}")
  done
  if selections="$(gum choose --no-limit --height 14 --header "$header" \
      --item.foreground 51 --cursor.foreground 51 --selected.foreground 10 --cursor-prefix '▸ ' \
      --selected-prefix '✓ ' --unselected-prefix '○ ' --padding '0 1' \
      "${selected_args[@]}" "${options[@]}")"; then
    :
  else
    if [[ "${BACK_ON_CANCEL:-false}" == true && "$?" != 130 ]]; then
      printf '%s' '__BACK__'
    else
      printf '%s' '__CANCEL__'
    fi
    return 0
  fi
  [[ -z "$selections" ]] && { printf '%s' ''; return; }
  while IFS= read -r selection; do
    [[ "$selection" == '← Back' ]] && { printf '%s' '__BACK__'; return; }
    [[ "$selection" == None ]] && continue
    result+="${selection}|"
  done <<< "$selections"
  printf '%s' "$result"
}

choose_many_back() { BACK_ON_CANCEL=true choose_many "$@" '← Back'; }

choose_many_back_current() {
  local current="$1" prompt="$2" footer="$3"
  shift 3
  local options=("$@") defaults='' index letter
  local letters=ABCDEFGHIJKLMNOPQRSTUVWXYZ
  for index in "${!options[@]}"; do
    letter="${letters:index:1}"
    selected "$current" "${options[$index]}" && defaults+="$letter"
  done
  BACK_ON_CANCEL=true choose_many "$prompt" "$defaults" "$footer" "${options[@]}" '← Back'
}

run_selection_category() {
  local category_index="$1"
  case "$category_index" in
    0) MENU_CHOICE="$(choose_terminal)"; [[ "$MENU_CHOICE" == __CANCEL__ || "$MENU_CHOICE" == __BACK__ ]] || TERMINAL="${MENU_CHOICE:-Ptyxis [pre-installed]}" ;;
    1) BACK_ON_CANCEL=true MENU_CHOICE="$(choose_described_many "$(file_manager_header)" "$FILE_MANAGERS" \
      $'\033[1mCarelo\033[0m            \033[38;5;250mDual pane GUI explorer. Simple. Clean.\033[0m|Carelo [dual-pane GUI; local-first]' \
      $'\033[1mYazi\033[0m              \033[38;5;250mRust, TUI file manager. Super snappy.\033[0m|Yazi [terminal; base plugins included]' \
      $'\033[1mSuperfile\033[0m          \033[38;5;250mModern, pretty TUI. Supports themes, plugins and previews.\033[0m|Superfile [modern TUI; themes, plugins and previews]' \
      $'\033[1mSpaceDrive\033[0m         \033[38;5;250mPaused project. Cloud storage first.\033[0m|Spacedrive [experimental v2 alpha; multi-device]' \
      $'← Back|← Back')"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || FILE_MANAGERS="$MENU_CHOICE" ;;
    2) BACK_ON_CANCEL=true MENU_CHOICE="$(choose_described_many "$(terminal_editor_header)" "$TERMINAL_EDITORS" \
      $'\033[1mNeovim\033[0m   \033[38;5;250mPowerful, extensible modal editor for serious customization.\033[0m|Neovim [optional]' \
      $'\033[1mMicro\033[0m     \033[38;5;250mModern, intuitive terminal editor with simple configuration.\033[0m|Micro [baseline]' \
      $'\033[1mNano\033[0m      \033[38;5;250mSimple, approachable terminal editor for quick edits.\033[0m|Nano [baseline]' \
      $'\033[1mFresh\033[0m     \033[38;5;250mModern terminal editor with a polished, responsive interface.\033[0m|Fresh [baseline]' \
      $'← Back|← Back')"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || TERMINAL_EDITORS="$MENU_CHOICE" ;;
    3) MENU_CHOICE="$(choose_many_back_current "$RESOURCE_MONITORS" 'System resource monitors' 'btop is the baseline terminal monitor.' 'Mission Center [feature-rich GUI; GPU, sensors, and processes]')"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || RESOURCE_MONITORS="$MENU_CHOICE" ;;
    4) MENU_CHOICE="$(choose_one_back_current "$MULTIPLEXER" 'Terminal multiplexer' 1 None 'Tmux [recommended]' 'Zellij [modern alternative]')"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || MULTIPLEXER="$MENU_CHOICE" ;;
    5) MENU_CHOICE="$(choose_many_back_current "$BROWSERS" 'Browsers' '' 'Chrome: With all the Google tracking you never asked for, but with AI features.' 'Chromium: The smarter option.' 'Firefox: Classically installed. Not the Snap version.')"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || BROWSERS="$MENU_CHOICE" ;;
    6) MENU_CHOICE="$(choose_one_back_current "$TILER" 'Tiling Management' 1 None 'O-Tiling [GNOME Shell extension; recommended]' 'Tiling Shell [GNOME Shell extension; alternative]' 'Simple Tiling [GNOME Shell extension; minimal fallback]' 'PaperWM [GNOME Shell extension; specialized alternative]')"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || TILER="$MENU_CHOICE" ;;
    7) MENU_CHOICE="$(choose_one_back_current "$SPEECH_TO_TEXT" 'Speech to text' 1 None 'Voxtype: Recommended.' 'Vocalinux: Low-resource VOSK option.' 'Speech Note: Mature offline desktop alternative.' 'Voquill: Polished cross-platform dictation. Account and trial flows.')"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || SPEECH_TO_TEXT="$MENU_CHOICE" ;;
    8) MENU_CHOICE="$(choose_many_back_current "$AGENTS" 'AI command-line agents' '' 'OpenAI Codex' 'Claude Code' 'OpenCode' 'GitHub Copilot CLI' 'Gemini CLI [alternative]' None)"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || AGENTS="$MENU_CHOICE" ;;
    9) MENU_CHOICE="$(choose_many_back_current "$OMARCHY_TOOLS" 'Ancillary tools' '' 'Lazygit' 'Gum' None)"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || OMARCHY_TOOLS="$MENU_CHOICE" ;;
    10) MENU_CHOICE="$(choose_many_back_current "$LOCAL_MODELS" 'Local model runner' '' 'Ollama [local model runner and API]' None)"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || LOCAL_MODELS="$MENU_CHOICE" ;;
    11) MENU_CHOICE="$(choose_many_back_current "$CONNECTIVITY" 'Connectivity additions' '' 'NetworkManager OpenVPN plugin [GNOME VPN integration]' None)"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || CONNECTIVITY="$MENU_CHOICE" ;;
    12) MENU_CHOICE="$(choose_many_back_current "$MAIL_CLIENTS" 'Mail clients' '' 'Thunderbird [Flatpak]' 'Betterbird [official Linux archive]' None)"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || MAIL_CLIENTS="$MENU_CHOICE" ;;
    13) MENU_CHOICE="$(choose_many_back_current "$LOGITECH_DEVICE_MANAGER" 'Logitech and gaming-mouse management' '' 'OpenLogi: Local-first Logitech Options+ replacement.' 'Piper + ratbagd [supported gaming mice]' None)"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || LOGITECH_DEVICE_MANAGER="$MENU_CHOICE" ;;
    14) MENU_CHOICE="$(choose_many_back_current "$SYNERGY_SELECTION" 'Keyboard and mouse sharing' '' 'Synergy [share input across machines]' None)"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || SYNERGY_SELECTION="$MENU_CHOICE" ;;
    15) MENU_CHOICE="$(choose_many_back_current "$DEV_TOOLCHAINS" 'Development toolchains' 'System Python remains available; selected toolchains become mise defaults.' 'Node.js LTS [recommended for CLI tools]' 'Python [current stable]' 'Rust [stable]' 'Go [current stable]' 'Java [current stable]')"; [[ "$MENU_CHOICE" == __BACK__ || "$MENU_CHOICE" == __CANCEL__ ]] || DEV_TOOLCHAINS="$MENU_CHOICE" ;;
    *) fatal "Unknown selection category: $category_index" ;;
  esac
}

selected() { [[ "|$1" == *"|$2|"* ]]; }

selection_keys=(
  TERMINAL FILE_MANAGERS TERMINAL_EDITORS RESOURCE_MONITORS MULTIPLEXER
  BROWSERS TILER SPEECH_TO_TEXT AGENTS OMARCHY_TOOLS LOCAL_MODELS CONNECTIVITY
  MAIL_CLIENTS LOGITECH_DEVICE_MANAGER SYNERGY_SELECTION DEV_TOOLCHAINS
)

load_selection_profile() {
  local profile_file="$1" key value
  [[ -r "$profile_file" ]] || fatal "Hydration profile is not readable: $profile_file"
  while IFS=$'\t' read -r key value || [[ -n "$key" ]]; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    if [[ "$key" == HYDRATOR_FORMAT_VERSION ]]; then
      [[ "$value" == 1 ]] || fatal "Unsupported hydration profile version: $value"
      continue
    fi
    if [[ " ${selection_keys[*]} " == *" $key "* ]]; then
      printf -v "$key" '%s' "$value"
    else
      fatal "Unknown key in hydration profile: $key"
    fi
  done < "$profile_file"

  local required_key
  for required_key in "${selection_keys[@]}"; do
    [[ -v "$required_key" ]] || fatal "Hydration profile is missing key: $required_key"
  done
}

export_selection_profile() {
  local profile_file="$1" key
  [[ -n "$profile_file" ]] || return 0
  mkdir -p "$(dirname -- "$profile_file")"
  {
    printf '# Hydrator selection profile\n'
    printf 'HYDRATOR_FORMAT_VERSION\t1\n'
    for key in "${selection_keys[@]}"; do
      printf '%s\t%s\n' "$key" "${!key}"
    done
  } > "$profile_file"
  pass "Hydration profile exported: $profile_file"
}

preview_heading() {
  gum style \
    --border rounded \
    --border-foreground 117 \
    --foreground 117 \
    --padding '0 1' \
    --bold \
    "$1"
}

mode_banner() {
  local width="${COLUMNS:-}" inner_width title='Hydrator' title_length left_pad right_pad
  local line label='( Preview )' label_length left_border right_border
  [[ "$width" =~ ^[0-9]+$ && "$width" -ge 32 ]] || width="$(tput cols 2>/dev/null || printf '80')"
  [[ "$width" =~ ^[0-9]+$ && "$width" -ge 32 ]] || width=80
  inner_width=$((width - 2))
  title_length=${#title}
  left_pad=$(( (inner_width - title_length) / 2 ))
  right_pad=$((inner_width - title_length - left_pad))
  printf -v line '%*s' "$inner_width" ''
  line=${line// /─}

  printf '\033[1;96m╭%s╮\033[0m\n' "$line"
  printf '\033[1;96m│%*s%s%*s│\033[0m\n' "$left_pad" '' "$title" "$right_pad" ''
  if [[ "$PREVIEW" == true ]]; then
    label_length=${#label}
    left_border=$(( (inner_width - label_length) / 2 ))
    right_border=$((inner_width - label_length - left_border))
    printf -v left_border '%*s' "$left_border" ''
    printf -v right_border '%*s' "$right_border" ''
    left_border=${left_border// /─}
    right_border=${right_border// /─}
    printf '\033[1;96m╰%s\033[38;5;208m%s\033[1;96m%s╯\033[0m\n' \
      "$left_border" "$label" "$right_border"
  else
    printf '\033[1;96m╰%s╯\033[0m\n' "$line"
  fi
}

preview_detail() {
  gum style --foreground 252 --padding '0 2' "$@"
}

preview_gnome_plan() {
  preview_heading 'GNOME performance policy'
  preview_detail \
    'These settings would be applied for the current user:' \
    '• Disable interface animations to reduce compositor work.' \
    '• Show the weekday in the clock.' \
    '• Set idle delay to 5 minutes.' \
    '• Suspend on battery after 15 minutes of inactivity.' \
    '• Do nothing on AC idle.' \
    '• Disable remembering recent files.' \
    '• Disable external search providers.' \
    '• Disable Ubuntu Dock and desktop-icons extensions.'
}

preview_extension_plan() {
  local extension_name extension_uuid extension_id
  preview_heading 'GNOME extension deployment'
  preview_detail \
    'All managed tiling extensions would first be disabled.' \
    'Only the selected extension would then be downloaded, installed, and enabled.'
  case "$TILER" in
    None)
      preview_detail 'Selected: None — no managed tiling extension would be enabled.'
      ;;
    'O-Tiling [GNOME Shell extension; recommended]')
      extension_name='O-Tiling'; extension_uuid='o-tiling@oliwebd.github.com'; extension_id=9875
      ;;
    'Tiling Shell [GNOME Shell extension; alternative]')
      extension_name='Tiling Shell'; extension_uuid='tilingshell@ferrarodomenico.com'; extension_id=7065
      ;;
    'Simple Tiling [GNOME Shell extension; minimal fallback]')
      extension_name='Simple Tiling'; extension_uuid='simple-tiling@domoel'; extension_id=8345
      ;;
    'PaperWM [GNOME Shell extension; specialized alternative]')
      extension_name='PaperWM'; extension_uuid='paperwm@paperwm.github.com'; extension_id=6099
      ;;
  esac
  if [[ -n "${extension_name:-}" ]]; then
    preview_detail \
      "Selected: $extension_name" \
      "Extension ID: $extension_id" \
      "UUID: $extension_uuid" \
      'A logout/login would be required for GNOME to activate the selected extension.'
  fi
}

preview_selection_plan() {
  preview_heading 'Hydration execution plan'
  preview_detail \
    'No command in this section will execute. This is the exact sequence the full run would follow after approval:' \
    '1. Validate Ubuntu, refresh APT metadata, and install the pre-hydration baseline.' \
    '2. Install and validate Gum and go-task before preference-sensitive choices.' \
    '3. Apply the selected power and GPU policy, if approved; reboot/login requirements are reported.' \
    '4. Detect active Snap services/processes, ask for confirmation, then remove and pin Snap.' \
    '5. Install the mandatory native APT application and shell baseline.' \
    '6. Install Linuxbrew, mise, Leaf, and the selected mise toolchains.' \
    '7. Add Flathub and install mandatory plus selected Flatpak applications.' \
    '8. Install selected vendor applications and configure their desktop launchers.' \
    '9. Deploy and enable only the selected GNOME tiling extension.' \
    '10. Apply and validate the GNOME performance policy.' \
    '11. Configure Kanata and selected user services.' \
    '12. Run final package, command, service, graphics, GNOME, and launcher validation.'

  preview_heading 'Selected choices'
  preview_detail \
    "Terminal: $TERMINAL" \
    "File managers: $(format_selections "$FILE_MANAGERS")" \
    "Terminal editors: $(format_selections "$TERMINAL_EDITORS")" \
    "Resource monitors: ${RESOURCE_MONITOR_SUMMARY:-btop (baseline)}" \
    "Multiplexer: $MULTIPLEXER" \
    "Browsers: $(format_selections "$BROWSERS")" \
    "Tiling management: $TILER" \
    "Speech to text: $SPEECH_TO_TEXT" \
    "AI agents: $(format_selections "$AGENTS")" \
    "Ancillary tools: $(format_selections "$OMARCHY_TOOLS")" \
    "Local models: $(format_selections "$LOCAL_MODELS")" \
    "Connectivity: $(format_selections "$CONNECTIVITY")" \
    "Mail clients: $(format_selections "$MAIL_CLIENTS")" \
    "Logitech device management: $(format_selections "$LOGITECH_DEVICE_MANAGER")" \
    "Keyboard/mouse sharing: $(format_selections "$SYNERGY_SELECTION")" \
    "Development toolchains: $(format_selections "$DEV_TOOLCHAINS")"

  preview_heading 'Mandatory and conditional delivery details'
  preview_detail \
    'Native APT baseline: ansilove, aptitude, bat, btop, ddgr, desktop-file-utils, eza, fastfetch, fd-find, fuse3, fwupd, fzf, gh, gnome-shell, gnome-shell-extension-manager, gnome-tweaks, intel-microcode, jq, kanata, micro, mpv, nala, podman, podman-compose, ripgrep, starship, thermald, timeshift, unzip, vim, wakeonlan, youtubedl-gui, yt-dlp, zoxide, and zsh.' \
    'Support baseline: Git, Gum, go-task, Flatpak/Flathub, GDebi/dpkg support, AppImage helpers, Linuxbrew, mise, Leaf, and the tracked shell configuration.' \
    'Mandatory Flatpaks: Obsidian, LocalSend, RustDesk, Podman Desktop, GNOME Podcasts, AppFlowy, Aurora Media Player, ncspot, and RustConn.' \
    'Vendor baseline: Beyond Compare 5, Tailscale, and Visual Studio Code Insiders.' \
    'Optional delivery uses the source documented for each selected item: APT, Flatpak, Linuxbrew, mise, official archive, AppImage, or vendor Debian package.'
  preview_gnome_plan
  preview_extension_plan
}

confirm_preview_plan() {
  preview_selection_plan
  choose_confirmation 'Preview complete. Approve this plan for a real installation? (Preview will make no changes.)' \
    && { preview_detail 'Preview approved. No installation was performed.'; return 0; }
  preview_detail 'Preview cancelled. No installation was performed.'
  return 1
}

confirm_hydration_overview() {
  mode_banner
  printf '\n%bUbuntu Hydrator%b\n' "$BRIGHT_CYAN" "$RESET"
  printf 'This workflow will configure Ubuntu power and GPU policy, remove and pin Snap,\n'
  printf 'apply selected GNOME optimizations, and install applications from your categories.\n'
  choose_confirmation 'Do you want to continue?' \
    || { printf 'Hydrator cancelled.\n'; exit 0; }
}

play_eclectic_alert() {
  local alert_file
  alert_file="$(mktemp -t eclectic-chaos-alert.XXXXXX.wav)"
  if command -v paplay >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    python3 - "$alert_file" <<'PY'
import math, struct, sys, wave

path = sys.argv[1]
sample_rate = 22050
notes = (659.25, 783.99, 987.77, 1318.51, 987.77, 783.99)
with wave.open(path, "w") as stream:
    stream.setnchannels(1)
    stream.setsampwidth(2)
    stream.setframerate(sample_rate)
    samples = []
    for index, frequency in enumerate(notes):
        for sample in range(int(sample_rate * 0.12)):
            envelope = min(1.0, sample / 400) * min(1.0, (sample_rate * 0.12 - sample) / 900)
            value = math.sin(2 * math.pi * frequency * sample / sample_rate)
            samples.append(struct.pack("<h", int(14000 * envelope * value)))
    stream.writeframes(b"".join(samples))
PY
    paplay "$alert_file" >/dev/null 2>&1 || true
  else
    printf '\a'
  fi
  rm -f -- "$alert_file"
}

run_power_management_phase() {
  status 'Power management profile'
  printf 'This configures the supported power profile. It may require a reboot.\n'
  if ! choose_confirmation "D'ya want it? Do ya? Do ya? Do ya?"; then
    warn 'Power optimization skipped by the user'
    return 0
  fi

  printf '%bThis is gonna hurt so good%b\n' "$BRIGHT_CYAN" "$RESET"
  "$LINUX_DIR/scripts/perf-pol.sh" --profile battery --power-only --non-interactive
  play_eclectic_alert
  next_step 'Reboot when prompted by the completed power phase, then resume hydration after login.'
}

run_nvidia_phase() {
  if ! lspci -nn 2>/dev/null | grep -qi nvidia; then
    pass 'No NVIDIA hardware detected; skipped NVIDIA configuration'
    return 0
  fi

  status 'NVIDIA compute configuration'
  printf 'This configures the NVIDIA GPU for compute workloads while Intel drives the desktop.\n'
  if ! choose_confirmation "D'ya want the NVIDIA settings? Do ya? Do ya? Do ya?"; then
    warn 'NVIDIA configuration skipped by the user'
    return 0
  fi
  "$LINUX_DIR/scripts/perf-pol.sh" --nvidia-only --non-interactive
  play_eclectic_alert
  next_step 'Reboot when prompted by the completed NVIDIA phase, then resume hydration after login.'
}

format_selections() {
  local selections="${1%|}"
  printf '%s' "${selections//|/, }"
}

configure_browser_launchers() {
  install -d "$USER_LOCAL_BIN" "$USER_APPLICATIONS"

  if selected "$BROWSERS" 'Chrome: With all the Google tracking you never asked for, but with AI features.' \
      && command -v google-chrome >/dev/null 2>&1; then
    configure_browser_launcher chrome
  fi

  if selected "$BROWSERS" 'Chromium: The smarter option.' \
      && sudo flatpak info org.chromium.Chromium >/dev/null 2>&1; then
    configure_browser_launcher chromium
  fi

  update-desktop-database "$USER_APPLICATIONS" >/dev/null 2>&1 \
    || warn "Could not refresh the user desktop-entry database after browser configuration"
}

# Each supported browser is an adapter inside this module. Callers only choose
# the browser; this module owns the wrapper and desktop-entry invariants.
configure_browser_launcher() {
  local browser="$1" label wrapper desktop name comment icon features launch_command
  case "$browser" in
    chrome)
      label="Google Chrome Wayland, GLIC, and touchpad gesture launcher"
      wrapper="$USER_LOCAL_BIN/dotfiles-google-chrome"
      desktop="$USER_APPLICATIONS/dotfiles-google-chrome.desktop"
      name="Google Chrome"
      comment="Access the Internet"
      icon="google-chrome"
      features="Glic,GlicActor,GlicActorUi,TouchpadOverscrollHistoryNavigation"
      launch_command="/usr/bin/google-chrome-stable"
      ;;
    chromium)
      label="Chromium Wayland and touchpad gesture launcher"
      wrapper="$USER_LOCAL_BIN/dotfiles-chromium"
      desktop="$USER_APPLICATIONS/dotfiles-chromium.desktop"
      name="Chromium Web Browser"
      comment="Access the Internet"
      icon="org.chromium.Chromium"
      features="TouchpadOverscrollHistoryNavigation"
      launch_command="flatpak run org.chromium.Chromium"
      ;;
    *)
      fatal "Unsupported browser launcher: $browser"
      ;;
  esac

  installing "$label"
  cat > "$wrapper" <<EOF
#!/usr/bin/env bash
set -euo pipefail

features='$features'
if [[ "\${XDG_SESSION_TYPE:-}" == wayland ]]; then
  features="WaylandWindowDecorations,\$features"
  exec $launch_command --ozone-platform=wayland --enable-features="\$features" "\$@"
fi
exec $launch_command --enable-features="\$features" "\$@"
EOF
  chmod 0755 "$wrapper"
  cat > "$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=$comment
Exec=$wrapper %U
TryExec=$wrapper
Icon=$icon
Terminal=false
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/pdf;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
EOF
  desktop-file-validate "$desktop"
  installed "$label"
}

validate_appimage_launch() {
  local label="$1" launcher="$2" launch_log result
  launch_log="$tmp_dir/${label// /-}.launch.log"
  set +e
  timeout 12 "$launcher" --version >"$launch_log" 2>&1
  result=$?
  set -e
  case "$result" in
    0)
      pass "$label started without errors"
      ;;
    124)
      pass "$label started and remained running for launch verification"
      ;;
    *)
      warn "$label launch output: $(head -1 "$launch_log" 2>/dev/null || true)"
      fail "$label failed launch verification"
      ;;
  esac
}

if [[ ! -r /etc/os-release ]]; then
  fatal "Cannot identify this operating system"
fi
. /etc/os-release
if [[ "${ID:-}" != ubuntu ]]; then
  fatal "This script supports Ubuntu only; found ${ID:-unknown}"
fi

if [[ "$PREVIEW" == false ]]; then
  sudo -v
fi

if [[ "$MODE" == gpu-integrated ]]; then
  sudo prime-select intel
  [[ "$(prime-select query)" == intel ]] || fatal "PRIME did not accept Intel mode"
  pass "Intel-only graphics selected; reboot to apply"
  exit 0
fi

if [[ "$MODE" == gpu-compute ]]; then
  sudo prime-select on-demand
  [[ "$(prime-select query)" == on-demand ]] || fatal "PRIME did not accept on-demand mode"
  pass "NVIDIA on-demand compute selected; reboot to apply"
  exit 0
fi

if [[ "$MODE" == apply ]]; then
  [[ -n "$SELECTIONS_FILE" && -r "$SELECTIONS_FILE" ]] \
    || fatal "Usage: $0 apply <selection-manifest>"
  # The manifest is emitted by this script with `declare -p` after the user
  # confirms the Gum summary. It is the interface consumed by Go Task.
  source "$SELECTIONS_FILE"
fi

if [[ "$MODE" == full ]]; then
  confirm_hydration_overview
elif [[ "$MODE" == preview ]]; then
  mode_banner
  preview_detail \
    'This runs the real Gum questionnaire and final approval flow.' \
    'It performs no system changes, creates no report, and does not execute installation commands.'
  choose_confirmation 'Continue with the non-mutating preview?' \
    || { preview_detail 'Preview cancelled. No system changes were made.'; exit 0; }
fi

if [[ "$MODE" == snap-only ]]; then
  status 'Checking Snap removal prerequisites'
  command -v gum >/dev/null 2>&1 || fatal 'Gum is required for snap-only UI'
  choose_confirmation 'Remove all installed Snap packages and prevent snapd from returning?' \
    || fatal 'Snap removal cancelled'
  status 'Removing Snap packages and preventing snapd from returning'
  remove_snap
  if ((VALIDATION_FAILURES > 0)); then
    fail "Snap-only test finished with $VALIDATION_FAILURES validation failure(s)"
    exit 1
  fi
  pass 'Snap-only test completed successfully'
  exit 0
fi

if [[ "$MODE" == full || "$MODE" == preview ]]; then
  if [[ "$MODE" == full ]]; then
    run_power_management_phase
    run_nvidia_phase
  else
    preview_heading 'Power and GPU policy (preview)'
    preview_detail \
      'The real run would offer the System76 Battery profile and NVIDIA compute/Intel-rendered desktop configuration.' \
      'No power profile, PRIME mode, driver, reboot, or GPU setting will be changed in preview mode.'
    choose_confirmation 'Continue to the Snap and application-selection preview?' \
      || { preview_detail 'Preview cancelled. No system changes were made.'; exit 0; }
  fi
  status 'Snap removal'
  choose_confirmation 'Do you want to remove Snap? It will take about 2 minutes before the next prompt' \
    || fatal 'Snap removal is required before application selection'
  if [[ "$MODE" == full ]]; then
    remove_snap
    pass 'All applications installed by this hydrator will use non-Snap sources'
  else
    preview_detail \
      'Preview: the real run would detect active Snap services/processes, stop confirmed services, remove Snap packages, and install the no-Snap policy.' \
      'No Snap command will execute in preview mode.'
  fi

  if [[ "$MODE" == full ]]; then
    bootstrap_hydration
  else
    preview_detail \
      'Preview: the real run would install and validate the pre-hydration baseline, including Git, Gum, go-task, Flatpak/Flathub, Linuxbrew, mise, and local-deb support.' \
      'The preview assumes Gum is already available so the questionnaire can be rendered.'
  fi

  printf '%bThis is finally the fun part. You will select applications by category.%b\n' \
    "$BRIGHT_CYAN" "$RESET"
  if [[ "$MODE" == full ]]; then
    printf 'Press any key to continue... '
    IFS= read -r -n 1 </dev/tty
    printf '\n'
  else
    preview_detail 'Preview: entering the real Gum questionnaire now.'
  fi

  clear </dev/tty 2>/dev/null || true
  hydrator_title
  printf '\n'

  TERMINAL='Ptyxis [pre-installed]'
  FILE_MANAGERS=''; TERMINAL_EDITORS=''; RESOURCE_MONITORS=''; MULTIPLEXER='None'
  BROWSERS=''; TILER='None'; SPEECH_TO_TEXT='None'; AGENTS=''; OMARCHY_TOOLS=''; LOCAL_MODELS=''
  CONNECTIVITY=''; MAIL_CLIENTS=''; LOGITECH_DEVICE_MANAGER=''; SYNERGY_SELECTION=''; DEV_TOOLCHAINS=''

  if [[ -n "$IMPORT_FILE" ]]; then
    load_selection_profile "$IMPORT_FILE"
    preview_detail "Loaded pre-configured hydration profile: $IMPORT_FILE"
  else
    menu_index=0
    while ((menu_index < 16)); do
      run_selection_category "$menu_index"
      case "$MENU_CHOICE" in
        __BACK__)
          if ((menu_index > 0)); then
            menu_index=$((menu_index - 1))
          else
            printf '\n%bHydration cancelled at the first category.%b\n' "$YELLOW" "$RESET"
            exit 0
          fi
          ;;
        __CANCEL__)
        printf '\n%bHydration cancelled. No further phases will run.%b\n' "$YELLOW" "$RESET"
        exit 0
          ;;
        *) menu_index=$((menu_index + 1)) ;;
      esac
    done
  fi
  RESOURCE_MONITOR_SUMMARY='btop (baseline)'
  if [[ -n "$RESOURCE_MONITORS" ]]; then
    RESOURCE_MONITOR_SUMMARY+=", $(format_selections "$RESOURCE_MONITORS")"
  fi

  if [[ "$MODE" == preview ]]; then
    export_selection_profile "$EXPORT_FILE"
    confirm_preview_plan || exit 0
    exit 0
  fi

  export_selection_profile "$EXPORT_FILE"

  printf '\nSelected: terminal=%s; file-managers=%s; terminal-editors=%s; resource-monitors=%s; multiplexer=%s; browsers=%s; tiling-management=%s; speech-to-text=%s; agents=%s; ancillary-tools=%s; local-models=%s; connectivity=%s; mail=%s; Logitech-device-management=%s; Synergy=%s; dev-toolchains=%s\n' \
  "$TERMINAL" "$(format_selections "$FILE_MANAGERS")" "$(format_selections "$TERMINAL_EDITORS")" "$RESOURCE_MONITOR_SUMMARY" \
  "$MULTIPLEXER" "$(format_selections "$BROWSERS")" "$TILER" "$SPEECH_TO_TEXT" "$(format_selections "$AGENTS")" \
    "$(format_selections "$OMARCHY_TOOLS")" "$(format_selections "$LOCAL_MODELS")" "$(format_selections "$CONNECTIVITY")" "$(format_selections "$MAIL_CLIENTS")" "$(format_selections "$LOGITECH_DEVICE_MANAGER")" "$(format_selections "$SYNERGY_SELECTION")" "$(format_selections "$DEV_TOOLCHAINS")"
  printf 'Press Enter to begin, or Ctrl+C to cancel. '
  IFS= read -r _ </dev/tty

  SELECTIONS_FILE="$REPORT_DIR/selections.sh"
  (umask 077; declare -p TERMINAL FILE_MANAGERS TERMINAL_EDITORS RESOURCE_MONITORS \
    MULTIPLEXER BROWSERS TILER SPEECH_TO_TEXT AGENTS OMARCHY_TOOLS LOCAL_MODELS \
    CONNECTIVITY MAIL_CLIENTS LOGITECH_DEVICE_MANAGER SYNERGY_SELECTION DEV_TOOLCHAINS > "$SELECTIONS_FILE")
  log "Delegating selected installation and configuration to Go Task"
  HYDRATE_SELECTIONS_FILE="$SELECTIONS_FILE" \
    task --taskfile "$LINUX_DIR/../../Taskfile.yml" hydrate:apply
  exit $?
fi

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf -- "$tmp_dir"; }
trap cleanup EXIT

run_hydration_tasks() {
log "Updating Ubuntu"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
sudo dpkg --audit | grep -q . && fail "dpkg reports incomplete packages" || pass "APT upgrade and package database validation passed"

remove_snap

log "Installing the native application and development SBOM"
apt_packages=(
  ansilove aptitude bat btop
  ddgr desktop-file-utils eza fastfetch fd-find fuse3 fwupd fzf gh
  gnome-shell gnome-shell-extension-manager gnome-tweaks intel-microcode jq kanata
  micro mpv nala podman podman-compose ripgrep
  starship thermald timeshift unzip vim wakeonlan youtubedl-gui yt-dlp zoxide zsh
)
selected "$TERMINAL" 'Ghostty [optional]' && apt_packages+=(ghostty)
selected "$TERMINAL" 'Alacritty [optional]' && apt_packages+=(alacritty)
selected "$TERMINAL" 'Foot [optional]' && apt_packages+=(foot)
selected "$TERMINAL_EDITORS" 'Neovim [optional]' && apt_packages+=(neovim)
case "$MULTIPLEXER" in
  'Tmux [recommended]') apt_packages+=(tmux) ;;
esac
if [[ "$SPEECH_TO_TEXT" == 'Voxtype: Recommended.' ]]; then
  apt_packages+=(wtype wl-clipboard libnotify-bin playerctl pipewire-alsa)
fi
selected "$OMARCHY_TOOLS" 'Lazygit' && apt_packages+=(lazygit)
selected "$CONNECTIVITY" 'NetworkManager OpenVPN plugin [GNOME VPN integration]' && apt_packages+=(network-manager-openvpn)
selected "$LOGITECH_DEVICE_MANAGER" 'Piper + ratbagd [supported gaming mice]' && apt_packages+=(piper ratbagd)
selected "$SYNERGY_SELECTION" 'Synergy [share input across machines]' && apt_packages+=(synergy)
if selected "$AGENTS" 'OpenAI Codex' \
  || selected "$AGENTS" 'OpenCode' \
  || selected "$AGENTS" 'GitHub Copilot CLI' \
  || selected "$AGENTS" 'Gemini CLI [alternative]'; then
  apt_packages+=(nodejs npm)
fi
available=()
unavailable=()
for package in "${apt_packages[@]}"; do
  if apt-cache show "$package" >/dev/null 2>&1; then
    available+=("$package")
  else
    unavailable+=("$package")
  fi
done
run_install "APT native applications and dependencies (${#available[@]} packages)" \
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${available[@]}"
if ((${#unavailable[@]})); then
  warn "Not present in enabled Ubuntu repositories: ${unavailable[*]}"
fi
for package in "${available[@]}"; do
  dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null | grep -q '^ii' \
    || fail "APT package validation failed: $package"
done
((VALIDATION_FAILURES == 0)) && pass "Native SBOM package validation passed"

install_homebrew() {
  local brew_bin
  if command -v brew >/dev/null 2>&1; then
    pass "Linuxbrew is already installed"
    return
  fi
  installing "Linuxbrew"
  if ! curl -fsSL --retry 3 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
      -o "$tmp_dir/install-homebrew.sh"; then
    return 1
  fi
  if ! NONINTERACTIVE=1 /bin/bash "$tmp_dir/install-homebrew.sh"; then
    return 1
  fi
  brew_bin=/home/linuxbrew/.linuxbrew/bin/brew
  [[ -x "$brew_bin" ]] || return 1
  eval "$("$brew_bin" shellenv)"
  if ! grep -Fxq 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' "$HOME/.profile" 2>/dev/null; then
    printf '\n# Linuxbrew\neval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"\n' >> "$HOME/.profile"
  fi
  installed "Linuxbrew"
}

install_mise() {
  local mise_bin="$HOME/.local/bin/mise"
  if command -v mise >/dev/null 2>&1; then
    pass "mise is already installed"
    return
  fi
  installing "mise"
  if ! curl -fsSL --retry 3 https://mise.run -o "$tmp_dir/install-mise.sh" \
    || ! sh "$tmp_dir/install-mise.sh" \
    || [[ ! -x "$mise_bin" ]]; then
    return 1
  fi
  installed "mise"
}

install_leaf() {
  local installer="$tmp_dir/install-leaf.sh"
  if command -v leaf >/dev/null 2>&1; then
    pass "Leaf is already installed"
    return
  fi
  installing "Leaf Markdown viewer"
  if ! curl -fsSL --retry 3 https://raw.githubusercontent.com/RivoLink/leaf/main/scripts/install.sh \
      -o "$installer" \
      || ! sh "$installer" "$USER_LOCAL_BIN" \
      || [[ ! -x "$USER_LOCAL_BIN/leaf" ]]; then
    return 1
  fi
  installed "Leaf Markdown viewer"
}

install_shell_baseline() {
  local tool
  local -a missing=()

  # Ubuntu packages expose these as batcat and fdfind.  The tracked Bash/Zsh
  # profiles deliberately use the upstream command names, so provide those
  # names before the profiles are sourced.
  install -d "$USER_LOCAL_BIN"
  if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
    ln -sfn "$(command -v batcat)" "$USER_LOCAL_BIN/bat"
  fi
  if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    ln -sfn "$(command -v fdfind)" "$USER_LOCAL_BIN/fd"
  fi

  for tool in bat eza fd fastfetch fzf git leaf micro rg starship zoxide; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if ((${#missing[@]})); then
    run_install "Mandatory shell tools via Linuxbrew: ${missing[*]}" brew install "${missing[@]}" \
      || return 1
  fi
  for tool in bat eza fd fastfetch fzf git leaf micro rg starship zoxide; do
    check_command "$tool" "Mandatory shell tool: $tool"
  done
}

log "Bootstrapping application-installation and development-tool managers"
install_homebrew || fail "Linuxbrew installation failed"
install_mise || fail "mise installation failed"
install_leaf || fail "Leaf Markdown viewer installation failed"
install_shell_baseline || fail "Mandatory shell baseline installation failed"
run_install "Mandatory shell configuration" task --taskfile "$LINUX_DIR/../../Taskfile.yml" hydrate:shell-config || fail "Mandatory shell configuration failed"

log "Installing Flatpak replacements for Snap and desktop applications"
run_install "Flathub remote" sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak_apps=(
  md.obsidian.Obsidian
  org.localsend.localsend_app
  com.rustdesk.RustDesk
  io.podman_desktop.PodmanDesktop
  org.gnome.Podcasts
  io.appflowy.AppFlowy
  io.github.daniacosta_dev.AuroraMediaPlayer
  io.github.hrkfdn.ncspot
  io.github.totoshko88.RustConn
)
selected "$MAIL_CLIENTS" 'Thunderbird [Flatpak]' && flatpak_apps+=(org.mozilla.Thunderbird)
selected "$BROWSERS" 'Firefox: Classically installed. Not the Snap version.' && flatpak_apps+=(org.mozilla.firefox)
selected "$BROWSERS" 'Chromium: The smarter option.' && flatpak_apps+=(org.chromium.Chromium)
selected "$RESOURCE_MONITORS" 'Mission Center [feature-rich GUI; GPU, sensors, and processes]' \
  && flatpak_apps+=(io.missioncenter.MissionCenter)
failed_flatpaks=()
for app_id in "${flatpak_apps[@]}"; do
  if ! run_install "Flatpak application: $app_id" sudo flatpak install -y --noninteractive flathub "$app_id"; then
    failed_flatpaks+=("$app_id")
  fi
done
if ((${#failed_flatpaks[@]})); then
  warn "Flatpak applications that failed: ${failed_flatpaks[*]}"
fi
for app_id in "${flatpak_apps[@]}"; do
  sudo flatpak info "$app_id" >/dev/null 2>&1 \
    && pass "Flatpak installed: $app_id" \
    || fail "Flatpak missing: $app_id"
done

log "Installing vendor-distributed desktop and network applications"
vendor_failures=()

if ! command -v bcompare >/dev/null 2>&1; then
  installing "Beyond Compare 5"
  if [[ "$(dpkg --print-architecture)" != amd64 ]]; then
    warn "Beyond Compare 5 currently publishes the reviewed Ubuntu installer only for amd64"
    vendor_failures+=(beyond-compare)
  elif curl -fL --retry 3 -o "$tmp_dir/bcompare.deb" \
      https://www.scootersoftware.com/files/bcompare-5.2.5.32528_amd64.deb; then
    run_install "Beyond Compare 5" sudo apt-get install -y "$tmp_dir/bcompare.deb" \
      || vendor_failures+=(beyond-compare)
  else
    vendor_failures+=(beyond-compare)
  fi
fi

log "Configuring the selected GNOME tiling extension"
tiling_uuids=(
  o-tiling@oliwebd.github.com
  tilingshell@ferrarodomenico.com
  simple-tiling@domoel
  paperwm@paperwm.github.com
)
for uuid in "${tiling_uuids[@]}"; do
  gnome-extensions disable "$uuid" 2>/dev/null || true
done
case "$TILER" in
  None)
    enabled_tiler=""
    for uuid in "${tiling_uuids[@]}"; do
      if gnome-extensions list --enabled | grep -Fxq "$uuid"; then
        enabled_tiler="$uuid"
        break
      fi
    done
    if [[ -z "$enabled_tiler" ]]; then
      pass "No managed GNOME tiling extension is enabled"
    else
      fail "GNOME tiling extension remains enabled: $enabled_tiler"
    fi
    ;;
  'O-Tiling [GNOME Shell extension; recommended]')
    install_gnome_extension 9875 o-tiling@oliwebd.github.com O-Tiling
    SESSION_RESTART_REQUIRED=true
    ;;
  'Tiling Shell [GNOME Shell extension; alternative]')
    install_gnome_extension 7065 tilingshell@ferrarodomenico.com "Tiling Shell"
    SESSION_RESTART_REQUIRED=true
    ;;
  'Simple Tiling [GNOME Shell extension; minimal fallback]')
    install_gnome_extension 8345 simple-tiling@domoel "Simple Tiling"
    SESSION_RESTART_REQUIRED=true
    ;;
  'PaperWM [GNOME Shell extension; specialized alternative]')
    install_gnome_extension 6099 paperwm@paperwm.github.com PaperWM
    SESSION_RESTART_REQUIRED=true
    ;;
esac

log "Installing selected offline speech-to-text application"
case "$SPEECH_TO_TEXT" in
  None)
    pass "No speech-to-text application selected"
    ;;
  'Voxtype: Recommended.')
    installing "Voxtype"
    if [[ "$(dpkg --print-architecture)" != amd64 ]]; then
      warn "Voxtype's Ubuntu release is currently selected only for amd64"
      vendor_failures+=(voxtype)
    elif ! command -v voxtype >/dev/null 2>&1; then
      voxtype_deb_url="$(curl -fsSL --retry 3 https://api.github.com/repos/peteonrails/voxtype/releases/latest \
        | jq -r '[.assets[] | select(.name | test("^voxtype_.*_amd64\\.deb$")) | .browser_download_url][0] // empty')"
      if [[ -n "$voxtype_deb_url" ]] \
        && curl -fL --retry 3 -o "$tmp_dir/voxtype.deb" "$voxtype_deb_url"; then
        run_install "Voxtype" sudo apt-get install -y "$tmp_dir/voxtype.deb" || vendor_failures+=(voxtype)
      else
        vendor_failures+=(voxtype)
      fi
    fi
    ;;
  'Vocalinux: Low-resource VOSK option.')
    installing "Vocalinux"
    vocalinux_url="$(curl -fsSL --retry 3 https://api.github.com/repos/VocaHQ/vocalinux/releases/latest \
      | jq -r '[.assets[] | select(.name | test("^Vocalinux-.*-x86_64\\.AppImage$")) | .browser_download_url][0] // empty')"
    if [[ -n "$vocalinux_url" ]] \
      && curl -fL --retry 3 -o "$tmp_dir/Vocalinux.AppImage" "$vocalinux_url"; then
      vocalinux_target="$USER_LOCAL_OPT/vocalinux/$(basename "$vocalinux_url" .AppImage)"
      install -d "$vocalinux_target" "$USER_LOCAL_BIN" "$USER_APPLICATIONS"
      install -m 0755 "$tmp_dir/Vocalinux.AppImage" "$vocalinux_target/Vocalinux.AppImage"
      ln -sfn "$vocalinux_target/Vocalinux.AppImage" "$USER_LOCAL_OPT/vocalinux/current"
      cat > "$USER_LOCAL_BIN/vocalinux" <<EOF
#!/usr/bin/env bash
exec env APPIMAGE_EXTRACT_AND_RUN=1 "$USER_LOCAL_OPT/vocalinux/current" "\$@"
EOF
      chmod 0755 "$USER_LOCAL_BIN/vocalinux"
      cat > "$USER_APPLICATIONS/Vocalinux.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Vocalinux
Comment=Offline Linux dictation
Exec=$USER_LOCAL_BIN/vocalinux
TryExec=$USER_LOCAL_BIN/vocalinux
Icon=audio-input-microphone
Terminal=false
Categories=Utility;AudioVideo;
EOF
      desktop-file-validate "$USER_APPLICATIONS/Vocalinux.desktop"
      installed "Vocalinux"
    else
      vendor_failures+=(vocalinux)
    fi
    ;;
  'Speech Note: Mature offline desktop alternative.')
    run_install "Speech Note" sudo flatpak install -y --noninteractive flathub net.mkiol.SpeechNote \
      || vendor_failures+=(speech-note)
    ;;
  'Voquill: Polished cross-platform dictation. Account and trial flows.')
    installing "Voquill"
    if [[ "$(dpkg --print-architecture)" != amd64 ]]; then
      warn "Voquill's official AppImage is currently selected only for amd64"
      vendor_failures+=(voquill)
    else
      mapfile -t voquill_release < <(curl -fsSL --retry 3 https://api.github.com/repos/voquill/voquill/releases/latest \
        | jq -r '[.tag_name, ([.assets[] | select(.name | test("^voquill-desktop_.*_amd64\\.AppImage$")) | .browser_download_url][0] // empty)] | .[]')
      voquill_version="${voquill_release[0]:-}"
      voquill_url="${voquill_release[1]:-}"
      voquill_target="$USER_LOCAL_OPT/voquill/$voquill_version"
      if [[ -n "$voquill_version" && -n "$voquill_url" ]] \
          && curl -fL --retry 3 -o "$tmp_dir/Voquill.AppImage" "$voquill_url"; then
        install -d "$voquill_target" "$USER_LOCAL_BIN" "$USER_APPLICATIONS"
        install -m 0755 "$tmp_dir/Voquill.AppImage" "$voquill_target/Voquill.AppImage"
        ln -sfn "$voquill_target/Voquill.AppImage" "$USER_LOCAL_OPT/voquill/current"
        cat > "$USER_LOCAL_BIN/voquill" <<EOF
#!/usr/bin/env bash
exec env APPIMAGE_EXTRACT_AND_RUN=1 "$USER_LOCAL_OPT/voquill/current" "\$@"
EOF
        chmod 0755 "$USER_LOCAL_BIN/voquill"
        cat > "$USER_APPLICATIONS/Voquill.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Voquill
Comment=Cross-platform dictation
Exec=$USER_LOCAL_BIN/voquill --no-sandbox
TryExec=$USER_LOCAL_BIN/voquill
Icon=audio-input-microphone
Terminal=false
Categories=Utility;AudioVideo;
EOF
        desktop-file-validate "$USER_APPLICATIONS/Voquill.desktop"
        installed "Voquill"
      else
        vendor_failures+=(voquill)
      fi
    fi
    ;;
esac
update-desktop-database "$USER_APPLICATIONS" >/dev/null 2>&1 || warn "Could not refresh desktop entries after speech application installation"

install_carelo() {
  local arch carelo_version carelo_url carelo_target carelo_root
  installing "Carelo"
  case "$(dpkg --print-architecture)" in
    amd64) arch=amd64 ;;
    *)
      warn "Carelo currently publishes Ubuntu artifacts only for amd64"
      return 1
      ;;
  esac
  mapfile -t carelo_release < <(curl -fsSL --retry 3 https://api.github.com/repos/aheinze/Carelo/releases/latest \
    | jq -r --arg arch "$arch" '[.tag_name, ([.assets[] | select(.name | test("^Carelo_.*_" + $arch + "\\.AppImage$")) | .browser_download_url][0] // empty)] | .[]')
  carelo_version="${carelo_release[0]:-}"
  carelo_url="${carelo_release[1]:-}"
  [[ -n "$carelo_version" && -n "$carelo_url" ]] || return 1
  carelo_target="$USER_LOCAL_OPT/carelo/$carelo_version"
  if [[ ! -x "$carelo_target/AppRun" ]]; then
    curl -fL --retry 3 -o "$tmp_dir/Carelo.AppImage" "$carelo_url"
    chmod +x "$tmp_dir/Carelo.AppImage"
    carelo_root="$tmp_dir/carelo-root"
    mkdir -p "$carelo_root"
    (cd "$carelo_root" && ./../Carelo.AppImage --appimage-extract >/dev/null)
    install -d "$carelo_target"
    cp -a "$carelo_root/squashfs-root/." "$carelo_target/"
  fi
  install -d "$USER_LOCAL_BIN" "$USER_APPLICATIONS" "$USER_ICONS" "$USER_LOCAL_OPT/carelo"
  ln -sfn "$carelo_version" "$USER_LOCAL_OPT/carelo/current"
  printf '%s\n' '#!/usr/bin/env sh' \
    "exec \"$USER_LOCAL_OPT/carelo/current/AppRun\" \"\$@\"" \
    > "$USER_LOCAL_BIN/carelo-launch"
  chmod 0755 "$USER_LOCAL_BIN/carelo-launch"
  ln -sfn "$USER_LOCAL_BIN/carelo-launch" "$USER_LOCAL_BIN/carelo"
  install -m 0644 "$carelo_target/usr/share/icons/hicolor/512x512/apps/carelo.png" \
    "$USER_ICONS/carelo.png"
  sed "s|^Exec=carelo$|Exec=$USER_LOCAL_BIN/carelo|" \
    "$carelo_target/usr/share/applications/Carelo.desktop" \
    | sed "s|^Icon=carelo$|Icon=$USER_ICONS/carelo.png|" \
    > "$USER_APPLICATIONS/Carelo.desktop"
  printf '%s\n' 'Keywords=file;files;folder;folders;compare;sync;' 'StartupNotify=true' \
    >> "$USER_APPLICATIONS/Carelo.desktop"
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 \
    || warn "Could not refresh the user icon cache"
  update-desktop-database "$USER_APPLICATIONS" >/dev/null 2>&1 || warn "Could not refresh the user desktop-entry database"
  installed "Carelo $carelo_version"
  next_step "Carelo: log out and back in before launching it from the Applications launcher."
  SESSION_RESTART_REQUIRED=true
}

install_yazi() {
  local arch yazi_version yazi_url yazi_target yazi_archive_root
  installing "Yazi and its base plugins"
  case "$(dpkg --print-architecture)" in
    amd64) arch=x86_64 ;;
    arm64) arch=aarch64 ;;
    *)
      warn "Yazi has no selected release artifact for architecture: $(dpkg --print-architecture)"
      return 1
      ;;
  esac
  mapfile -t yazi_release < <(curl -fsSL --retry 3 https://api.github.com/repos/sxyazi/yazi/releases/latest \
    | jq -r --arg arch "$arch" '[.tag_name, ([.assets[] | select(.name == ("yazi-" + $arch + "-unknown-linux-gnu.zip")) | .browser_download_url][0] // empty)] | .[]')
  yazi_version="${yazi_release[0]:-}"
  yazi_url="${yazi_release[1]:-}"
  [[ -n "$yazi_version" && -n "$yazi_url" ]] || return 1
  yazi_target="$USER_LOCAL_OPT/yazi/$yazi_version"
  if [[ ! -x "$yazi_target/yazi" || ! -x "$yazi_target/ya" ]]; then
    curl -fL --retry 3 -o "$tmp_dir/yazi.zip" "$yazi_url"
    unzip -q "$tmp_dir/yazi.zip" -d "$tmp_dir/yazi-root"
    yazi_archive_root="$tmp_dir/yazi-root/yazi-$arch-unknown-linux-gnu"
    [[ -x "$yazi_archive_root/yazi" && -x "$yazi_archive_root/ya" ]] || return 1
    install -d "$yazi_target"
    cp -a "$yazi_archive_root/." "$yazi_target/"
  fi
  install -d "$USER_LOCAL_BIN" "$USER_LOCAL_OPT/yazi"
  ln -sfn "$yazi_version" "$USER_LOCAL_OPT/yazi/current"
  ln -sfn "$USER_LOCAL_OPT/yazi/current/yazi" "$USER_LOCAL_BIN/yazi"
  ln -sfn "$USER_LOCAL_OPT/yazi/current/ya" "$USER_LOCAL_BIN/ya"
  ya pkg add yazi-rs/plugins:git yazi-rs/plugins:smart-enter \
    yazi-rs/plugins:jump-to-char yazi-rs/plugins:toggle-pane \
    yazi-rs/plugins:diff yazi-rs/plugins:smart-paste
  installed "Yazi $yazi_version and base plugins"
}

install_spacedrive() {
  local arch spacedrive_version spacedrive_url spacedrive_target
  installing "Spacedrive v2 alpha"
  case "$(dpkg --print-architecture)" in
    amd64) arch=x86_64 ;;
    arm64) arch=aarch64 ;;
    *)
      warn "Spacedrive has no selected v2 release artifact for architecture: $(dpkg --print-architecture)"
      return 1
      ;;
  esac
  mapfile -t spacedrive_release < <(curl -fsSL --retry 3 'https://api.github.com/repos/spacedriveapp/spacedrive/releases?per_page=100' \
    | jq -r --arg arch "$arch" '([.[] | select(.prerelease and (.tag_name | startswith("v2.")))][0]) as $release | [$release.tag_name, ([$release.assets[] | select(.name == ("Spacedrive-linux-" + $arch + ".deb")) | .browser_download_url][0] // empty)] | .[]')
  spacedrive_version="${spacedrive_release[0]:-}"
  spacedrive_url="${spacedrive_release[1]:-}"
  [[ -n "$spacedrive_version" && -n "$spacedrive_url" ]] || return 1
  spacedrive_target="$USER_LOCAL_OPT/spacedrive/$spacedrive_version"
  if [[ ! -x "$spacedrive_target/usr/bin/Spacedrive" ]]; then
    curl -fL --retry 3 -o "$tmp_dir/spacedrive.deb" "$spacedrive_url"
    dpkg-deb -x "$tmp_dir/spacedrive.deb" "$tmp_dir/spacedrive-root"
    [[ -x "$tmp_dir/spacedrive-root/usr/bin/Spacedrive" ]] || return 1
    install -d "$spacedrive_target"
    cp -a "$tmp_dir/spacedrive-root/usr" "$spacedrive_target/"
  fi
  install -d "$USER_LOCAL_BIN" "$USER_APPLICATIONS" "$USER_LOCAL_OPT/spacedrive"
  ln -sfn "$spacedrive_version" "$USER_LOCAL_OPT/spacedrive/current"
  ln -sfn "$USER_LOCAL_OPT/spacedrive/current/usr/bin/Spacedrive" "$USER_LOCAL_BIN/spacedrive"
  ln -sfn "$USER_LOCAL_OPT/spacedrive/current/usr/bin/Spacedrive" "$USER_LOCAL_BIN/Spacedrive"
  sed "s|^Exec=Spacedrive$|Exec=$USER_LOCAL_BIN/spacedrive|" \
    "$spacedrive_target/usr/share/applications/Spacedrive.desktop" > "$USER_APPLICATIONS/Spacedrive.desktop"
  installed "Spacedrive $spacedrive_version"
}

log "Installing selected file managers"
if selected "$FILE_MANAGERS" 'Carelo [dual-pane GUI; local-first]'; then
  install_carelo || vendor_failures+=(carelo)
fi
if selected "$FILE_MANAGERS" 'Yazi [terminal; base plugins included]'; then
  install_yazi || vendor_failures+=(yazi)
fi
if selected "$FILE_MANAGERS" 'Spacedrive [experimental v2 alpha; multi-device]'; then
  install_spacedrive || vendor_failures+=(spacedrive)
fi

log "Installing selected terminal editor and multiplexer"
if ! command -v fresh >/dev/null 2>&1; then
  installing "Fresh Editor"
  fresh_arch="$(dpkg --print-architecture)"
  fresh_deb_url="$(curl -fsSL --retry 3 https://api.github.com/repos/sinelaw/fresh/releases/latest \
    | jq -r --arg arch "$fresh_arch" \
      '[.assets[] | select(.name | test("^fresh-editor_.*-1_" + $arch + "\\.deb$")) | .browser_download_url][0] // empty')"
  if [[ -n "$fresh_deb_url" ]] \
    && curl -fL --retry 3 -o "$tmp_dir/fresh.deb" "$fresh_deb_url"; then
    run_install "Fresh Editor" sudo apt-get install -y "$tmp_dir/fresh.deb" || vendor_failures+=(fresh)
  else
    vendor_failures+=(fresh)
  fi
fi
if [[ "$MULTIPLEXER" == 'Zellij [modern alternative]' ]] \
  && ! command -v zellij >/dev/null 2>&1; then
  installing "Zellij"
  zellij_arch="$(uname -m)"
  case "$zellij_arch" in
    x86_64|aarch64) ;;
    *)
      warn "Zellij has no selected release asset for architecture: $zellij_arch"
      vendor_failures+=(zellij)
      zellij_arch=""
      ;;
  esac
  if [[ -n "$zellij_arch" ]]; then
    zellij_url="$(curl -fsSL --retry 3 https://api.github.com/repos/zellij-org/zellij/releases/latest \
      | jq -r --arg arch "$zellij_arch" \
        '[.assets[] | select(.name == ("zellij-" + $arch + "-unknown-linux-musl.tar.gz")) | .browser_download_url][0] // empty')"
    if [[ -n "$zellij_url" ]] \
      && curl -fL --retry 3 -o "$tmp_dir/zellij.tar.gz" "$zellij_url" \
      && mkdir -p "$tmp_dir/zellij" \
      && tar -xzf "$tmp_dir/zellij.tar.gz" -C "$tmp_dir/zellij" \
      && [[ -f "$tmp_dir/zellij/zellij" ]]; then
      install -D -m 0755 "$tmp_dir/zellij/zellij" "$HOME/.local/bin/zellij"
      installed "Zellij"
    else
      vendor_failures+=(zellij)
    fi
  fi
fi

if selected "$BROWSERS" 'Chrome: With all the Google tracking you never asked for, but with AI features.' \
    && ! command -v google-chrome >/dev/null 2>&1; then
  installing "Google Chrome"
  if curl -fL --retry 3 -o "$tmp_dir/google-chrome.deb" \
      https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb; then
    run_install "Google Chrome" sudo apt-get install -y "$tmp_dir/google-chrome.deb" || vendor_failures+=(google-chrome)
  else
    vendor_failures+=(google-chrome)
  fi
fi

configure_browser_launchers

if selected "$LOGITECH_DEVICE_MANAGER" 'OpenLogi: Local-first Logitech Options+ replacement.' \
    && ! command -v openlogi >/dev/null 2>&1; then
  installing "OpenLogi"
  openlogi_arch="$(dpkg --print-architecture)"
  openlogi_url="$(curl -fsSL --retry 3 https://api.github.com/repos/AprilNEA/OpenLogi/releases/latest \
    | jq -r --arg arch "$openlogi_arch" \
      '[.assets[] | select(.name | test("^openlogi-v.*-linux-" + $arch + "\\.deb$")) | .browser_download_url][0] // empty')"
  if [[ -n "$openlogi_url" ]] \
      && curl -fL --retry 3 -o "$tmp_dir/openlogi.deb" "$openlogi_url"; then
    run_install "OpenLogi" sudo apt-get install -y "$tmp_dir/openlogi.deb" || vendor_failures+=(openlogi)
  else
    vendor_failures+=(openlogi)
  fi
fi

install_betterbird() {
  local archive target
  command -v betterbird >/dev/null 2>&1 && return
  installing "Betterbird"
  archive="$tmp_dir/betterbird.tar.xz"
  target="$USER_LOCAL_OPT/betterbird/current"
  if ! curl -fL --retry 3 \
      'https://www.betterbird.eu/downloads/get.php?os=linux&lang=en-US&version=release' \
      -o "$archive"; then
    return 1
  fi
  rm -rf -- "$target"
  install -d "$target" "$USER_LOCAL_BIN" "$USER_APPLICATIONS"
  tar -xJf "$archive" -C "$target" --strip-components=1
  [[ -x "$target/betterbird" ]] || return 1
  ln -sfn "$target/betterbird" "$USER_LOCAL_BIN/betterbird"
  cat > "$USER_APPLICATIONS/betterbird.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Betterbird
Comment=Mail and calendar client
Exec=$USER_LOCAL_BIN/betterbird %u
TryExec=$USER_LOCAL_BIN/betterbird
Icon=$target/chrome/icons/default/default128.png
Terminal=false
Categories=Network;Email;
MimeType=x-scheme-handler/mailto;
EOF
  desktop-file-validate "$USER_APPLICATIONS/betterbird.desktop"
  installed "Betterbird"
}

if selected "$MAIL_CLIENTS" 'Betterbird [official Linux archive]'; then
  install_betterbird || vendor_failures+=(betterbird)
fi

log "Installing selected AI agents"
if selected "$AGENTS" 'OpenAI Codex'; then
  run_install "OpenAI Codex" sudo npm install -g @openai/codex || vendor_failures+=(codex)
fi
if selected "$AGENTS" 'OpenCode'; then
  run_install "OpenCode" sudo npm install -g opencode-ai || vendor_failures+=(opencode)
fi
if selected "$AGENTS" 'GitHub Copilot CLI'; then
  run_install "GitHub Copilot CLI" sudo npm install -g @github/copilot || vendor_failures+=(copilot)
fi
if selected "$AGENTS" 'Gemini CLI [alternative]'; then
  run_install "Gemini CLI" sudo npm install -g @google/gemini-cli || vendor_failures+=(gemini-cli)
fi
if selected "$AGENTS" 'Claude Code'; then
  installing "Claude Code"
  if curl -fsSL https://claude.ai/install.sh -o "$tmp_dir/install-claude.sh"; then
    if sh "$tmp_dir/install-claude.sh"; then
      installed "Claude Code"
    else
      vendor_failures+=(claude-code)
    fi
  else
    vendor_failures+=(claude-code)
  fi
fi

log "Installing selected mise development toolchains"
if selected "$DEV_TOOLCHAINS" 'Node.js LTS [recommended for CLI tools]'; then
  run_install "mise toolchain: Node.js LTS" mise use --global node@lts || vendor_failures+=(mise-node)
fi
if selected "$DEV_TOOLCHAINS" 'Python [current stable]'; then
  run_install "mise toolchain: Python" mise use --global python@latest || vendor_failures+=(mise-python)
fi
if selected "$DEV_TOOLCHAINS" 'Rust [stable]'; then
  run_install "mise toolchain: Rust" mise use --global rust@stable || vendor_failures+=(mise-rust)
fi
if selected "$DEV_TOOLCHAINS" 'Go [current stable]'; then
  run_install "mise toolchain: Go" mise use --global go@latest || vendor_failures+=(mise-go)
fi
if selected "$DEV_TOOLCHAINS" 'Java [current stable]'; then
  run_install "mise toolchain: Java" mise use --global java@latest || vendor_failures+=(mise-java)
fi
if [[ -n "$DEV_TOOLCHAINS" ]]; then
  run_install "mise global shims" mise reshim || vendor_failures+=(mise-reshim)
  if ! grep -Fxq 'export PATH="$HOME/.local/share/mise/shims:$PATH"' "$HOME/.profile" 2>/dev/null; then
    printf '\n# mise global toolchain shims\nexport PATH="$HOME/.local/share/mise/shims:$PATH"\n' >> "$HOME/.profile"
  fi
fi

if ! command -v tailscale >/dev/null 2>&1; then
  installing "Tailscale"
  if curl -fsSL https://tailscale.com/install.sh -o "$tmp_dir/install-tailscale.sh"; then
    if sudo sh "$tmp_dir/install-tailscale.sh"; then
      installed "Tailscale"
    else
      vendor_failures+=(tailscale)
    fi
  else
    vendor_failures+=(tailscale)
  fi
fi

if ! command -v code-insiders >/dev/null 2>&1; then
  installing "Visual Studio Code Insiders"
  if curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o "$tmp_dir/microsoft.asc"; then
    gpg --dearmor < "$tmp_dir/microsoft.asc" > "$tmp_dir/packages.microsoft.gpg"
    sudo install -D -m 0644 "$tmp_dir/packages.microsoft.gpg" /usr/share/keyrings/packages.microsoft.gpg
    printf '%s\n' 'deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main' \
      | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update
    if sudo apt-get install -y code-insiders; then
      installed "Visual Studio Code Insiders"
    else
      vendor_failures+=(code-insiders)
    fi
  else
    vendor_failures+=(code-insiders)
  fi
fi

if selected "$LOCAL_MODELS" 'Ollama [local model runner and API]' \
    && ! command -v ollama >/dev/null 2>&1; then
  installing "Ollama"
  if curl -fsSL https://ollama.com/install.sh -o "$tmp_dir/install-ollama.sh"; then
    if sudo sh "$tmp_dir/install-ollama.sh"; then
      installed "Ollama"
    else
      vendor_failures+=(ollama)
    fi
  else
    vendor_failures+=(ollama)
  fi
fi
if ((${#vendor_failures[@]})); then
  warn "Vendor applications that failed: ${vendor_failures[*]}"
fi
if selected "$BROWSERS" 'Chrome: With all the Google tracking you never asked for, but with AI features.'; then
  check_command google-chrome "Google Chrome"
  [[ -x "$USER_LOCAL_BIN/dotfiles-google-chrome" ]] \
    && pass "Google Chrome custom launcher is executable" \
    || fail "Google Chrome custom launcher is missing"
  desktop-file-validate "$USER_APPLICATIONS/dotfiles-google-chrome.desktop" \
    && pass "Google Chrome custom desktop entry is valid" \
    || fail "Google Chrome custom desktop entry is invalid"
fi
if selected "$BROWSERS" 'Chromium: The smarter option.'; then
  sudo flatpak info org.chromium.Chromium >/dev/null 2>&1 \
    && pass "Chromium is installed" \
    || fail "Chromium is not installed"
  [[ -x "$USER_LOCAL_BIN/dotfiles-chromium" ]] \
    && pass "Chromium custom launcher is executable" \
    || fail "Chromium custom launcher is missing"
  desktop-file-validate "$USER_APPLICATIONS/dotfiles-chromium.desktop" \
    && pass "Chromium custom desktop entry is valid" \
    || fail "Chromium custom desktop entry is invalid"
fi
if selected "$LOGITECH_DEVICE_MANAGER" 'OpenLogi: Local-first Logitech Options+ replacement.'; then
  check_command openlogi OpenLogi
fi
check_command tailscale Tailscale
check_command code-insiders "Code Insiders"
selected "$LOCAL_MODELS" 'Ollama [local model runner and API]' && check_command ollama Ollama
check_command bcompare "Beyond Compare 5"
if selected "$FILE_MANAGERS" 'Carelo [dual-pane GUI; local-first]'; then
  check_command carelo Carelo
  [[ -x "$USER_LOCAL_OPT/carelo/current/AppRun" ]] \
    && pass "Carelo AppRun wrapper is available" \
    || fail "Carelo AppRun wrapper is missing"
fi
if selected "$FILE_MANAGERS" 'Yazi [terminal; base plugins included]'; then
  check_command yazi Yazi
  check_command ya "Yazi package manager"
  for yazi_plugin in git smart-enter jump-to-char toggle-pane diff smart-paste; do
    ya pkg list | grep -Fq "yazi-rs/plugins:$yazi_plugin" \
      && pass "Yazi base plugin installed: $yazi_plugin" \
      || fail "Yazi base plugin missing: $yazi_plugin"
  done
fi
if selected "$FILE_MANAGERS" 'Spacedrive [experimental v2 alpha; multi-device]'; then
  check_command spacedrive Spacedrive
  [[ -x "$USER_LOCAL_OPT/spacedrive/current/usr/bin/sd-daemon" ]] \
    && pass "Spacedrive v2 daemon is available" \
    || fail "Spacedrive v2 daemon is missing"
fi
check_command nano Nano
check_command vim Vim
check_command btop btop
check_command brew Linuxbrew
check_command mise mise
check_command leaf Leaf
check_command micro Micro
check_command fresh Fresh
selected "$TERMINAL_EDITORS" 'Neovim [optional]' && check_command nvim Neovim
if selected "$RESOURCE_MONITORS" 'Mission Center [feature-rich GUI; GPU, sensors, and processes]'; then
  sudo flatpak info io.missioncenter.MissionCenter >/dev/null 2>&1 \
    && pass "Mission Center is installed" \
    || fail "Mission Center is not installed"
fi
if selected "$DEV_TOOLCHAINS" 'Node.js LTS [recommended for CLI tools]'; then
  mise exec node -- node --version >/dev/null \
    && pass "mise Node.js toolchain is runnable" \
    || fail "mise Node.js toolchain is not runnable"
fi
if selected "$DEV_TOOLCHAINS" 'Python [current stable]'; then
  mise exec python -- python --version >/dev/null \
    && pass "mise Python toolchain is runnable" \
    || fail "mise Python toolchain is not runnable"
fi
if selected "$DEV_TOOLCHAINS" 'Rust [stable]'; then
  mise exec rust -- rustc --version >/dev/null \
    && pass "mise Rust toolchain is runnable" \
    || fail "mise Rust toolchain is not runnable"
fi
if selected "$DEV_TOOLCHAINS" 'Go [current stable]'; then
  mise exec go -- go version >/dev/null \
    && pass "mise Go toolchain is runnable" \
    || fail "mise Go toolchain is not runnable"
fi
if selected "$DEV_TOOLCHAINS" 'Java [current stable]'; then
  mise exec java -- java --version >/dev/null \
    && pass "mise Java toolchain is runnable" \
    || fail "mise Java toolchain is not runnable"
fi
case "$MULTIPLEXER" in
  'Tmux [recommended]') check_command tmux Tmux ;;
  'Zellij [modern alternative]') check_command zellij Zellij ;;
esac
selected "$AGENTS" 'OpenAI Codex' && check_command codex "OpenAI Codex"
selected "$AGENTS" 'Claude Code' && check_command claude "Claude Code"
selected "$AGENTS" 'OpenCode' && check_command opencode OpenCode
selected "$AGENTS" 'GitHub Copilot CLI' && check_command copilot "GitHub Copilot CLI"
selected "$AGENTS" 'Gemini CLI [alternative]' && check_command gemini "Gemini CLI"
selected "$OMARCHY_TOOLS" 'Lazygit' && check_command lazygit Lazygit
selected "$OMARCHY_TOOLS" 'Gum' && check_command gum Gum
check_command yt-dlp yt-dlp
selected "$MAIL_CLIENTS" 'Thunderbird [Flatpak]' \
  && sudo flatpak info org.mozilla.Thunderbird >/dev/null 2>&1 \
  && pass "Thunderbird is installed" \
  || true
selected "$MAIL_CLIENTS" 'Betterbird [official Linux archive]' && check_command betterbird Betterbird
case "$SPEECH_TO_TEXT" in
  'Voxtype: Recommended.')
    check_command voxtype Voxtype
    ;;
  'Vocalinux: Low-resource VOSK option.')
    [[ -x "$USER_LOCAL_BIN/vocalinux" ]] \
      && pass "Vocalinux is installed in ~/.local/bin" \
      || fail "Vocalinux is not installed in ~/.local/bin"
    validate_appimage_launch Vocalinux "$USER_LOCAL_BIN/vocalinux"
    ;;
  'Speech Note: Mature offline desktop alternative.')
    sudo flatpak info net.mkiol.SpeechNote >/dev/null 2>&1 \
      && pass "Speech Note is installed" \
      || fail "Speech Note is not installed"
    ;;
  'Voquill: Polished cross-platform dictation. Account and trial flows.')
    [[ -x "$USER_LOCAL_BIN/voquill" ]] \
      && pass "Voquill is installed in ~/.local/bin" \
      || fail "Voquill is not installed in ~/.local/bin"
    validate_appimage_launch Voquill "$USER_LOCAL_BIN/voquill"
    ;;
esac

log "Installing and enabling the power-management stack"
run_install "TLP and thermald" sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y tlp thermald
sudo systemctl disable --now power-profiles-daemon.service 2>/dev/null || true
sudo systemctl mask power-profiles-daemon.service 2>/dev/null || true
sudo install -D -m 0644 "$LINUX_DIR/config/tlp/50-dotfiles-workstation.conf" /etc/tlp.d/50-dotfiles-workstation.conf
sudo systemctl enable --now tlp.service thermald.service
sudo tlp start
check_service tlp.service
check_service thermald.service
[[ "$(systemctl is-enabled power-profiles-daemon.service 2>/dev/null || true)" == masked ]] \
  && pass "power-profiles-daemon is masked" \
  || fail "power-profiles-daemon is not masked"

log "Configuring Intel-only graphics for maximum battery life"
if lspci -nn | grep -qi NVIDIA; then
  sudo ubuntu-drivers install
  if command -v prime-select >/dev/null 2>&1; then
    current_prime="$(prime-select query 2>/dev/null || true)"
    if [[ "$current_prime" != intel ]]; then
      sudo prime-select intel
      REBOOT_REQUIRED=true
    fi
  fi
fi
[[ "$(prime-select query 2>/dev/null || true)" == intel ]] \
  && pass "PRIME is configured for Intel-only graphics" \
  || fail "PRIME is not configured for Intel-only graphics"

log "Applying GNOME optimization policy"
"$LINUX_DIR/scripts/gnome-optimize.sh" --all
[[ "$(gsettings get org.gnome.desktop.interface enable-animations 2>/dev/null)" == false ]] \
  && pass "GNOME animations are disabled" \
  || fail "GNOME animation setting validation failed"

log "Installing Kanata as a privileged system service"
sudo install -D -m 0644 "$LINUX_DIR/config/kanata/kanata.kbd" /etc/kanata/kanata.kbd
sudo kanata --check --cfg /etc/kanata/kanata.kbd
pass "Kanata configuration parses successfully"
sudo install -D -m 0644 "$LINUX_DIR/config/systemd/system/kanata.service" /etc/systemd/system/kanata.service
sudo systemctl daemon-reload
sudo systemctl enable --now kanata.service
check_service kanata.service
run_install "Kanata user keymap symlink" \
  task --taskfile "$LINUX_DIR/../../Taskfile.yml" kanata:config
kanata_link="$HOME/.config/kanata/kanata.kbd"
if [[ -L "$kanata_link" && "$(readlink -f "$kanata_link")" == "$(readlink -f "$LINUX_DIR/config/kanata/kanata.kbd")" ]]; then
  pass "Kanata user keymap symlink targets the tracked Linux configuration"
else
  fail "Kanata user keymap symlink is missing or targets the wrong configuration"
fi
# Older revisions of tasks/kanata.yml created a competing user service. The
# privileged system service above is the only service hydration may enable.
systemctl --user disable --now kanata.service 2>/dev/null || true

log "Enabling workstation services"
sudo systemctl enable --now thermald.service
systemctl --user enable --now podman.socket 2>/dev/null || true

log "Cleaning packages and verifying policy"
sudo apt-get autoremove -y
if command -v snap >/dev/null 2>&1 || dpkg-query -W -f='${db:Status-Abbrev}' snapd 2>/dev/null | grep -q '^ii'; then
  fail "Snap removal verification failed"
else
  pass "Snap remains absent after cleanup"
fi

printf '\nHydration report: %s\n' "$REPORT_FILE"
printf 'PRIME mode: %s\n' "$(prime-select query 2>/dev/null || printf 'not applicable')"
printf 'TLP: %s\n' "$(systemctl is-active tlp.service 2>/dev/null || true)"
printf 'Kanata: %s\n' "$(systemctl is-active kanata.service 2>/dev/null || true)"
if [[ "$SPEECH_TO_TEXT" != None ]]; then
  printf '%bComplete the selected speech-to-text app first-run model setup before dictating.%b\n' \
    "$YELLOW" "$RESET"
fi
# A new login gives GNOME a clean view of newly registered applications and
# extensions, and loads the profile changes made for Linuxbrew and mise.
# Keep this visible even when a later validation makes the run unsuccessful.
next_step "Log out and back in after hydration so GNOME, application launchers, extensions, and shell-profile changes take effect."
if ((VALIDATION_FAILURES > 0)); then
  printf '%bHydration finished with %d validation failure(s).%b\n' "$RED" "$VALIDATION_FAILURES" "$RESET"
  exit 1
fi
pass "All required hydration validations passed"
if [[ "$REBOOT_REQUIRED" == true || -f /var/run/reboot-required ]]; then
  printf '%bA reboot is required to finish hydration.%b\n' "$YELLOW" "$RESET"
fi
if [[ "$SESSION_RESTART_REQUIRED" == true ]]; then
  printf '%bThe required logout/login will also make Carelo discoverable from the Applications launcher and activate any selected GNOME extension.%b\n' "$YELLOW" "$RESET"
fi
}

run_hydration_tasks
