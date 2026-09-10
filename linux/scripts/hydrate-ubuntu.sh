#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
VICTUALS_CATALOG_DIR="${VICTUALS_CATALOG_DIR:-$LINUX_DIR/../victuals/definitions}"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/victuals-catalog.sh"
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

mkdir -p "$REPORT_DIR"
export PATH="$USER_LOCAL_BIN:$PATH"
exec > >(tee "$REPORT_FILE") 2>&1

log() { printf '\n%b==> %s%b\n' "$BLUE" "$*" "$RESET"; }
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
fail() {
  printf '%bFAIL: %s%b\n' "$RED" "$*" "$RESET" >&2
  VALIDATION_FAILURES=$((VALIDATION_FAILURES + 1))
}
fatal() { printf '%bFATAL: %s%b\n' "$RED" "$*" "$RESET" >&2; exit 1; }
trap 'fatal "Hydration stopped at line $LINENO while running: $BASH_COMMAND"' ERR

check_command() {
  local command_name="$1" label="${2:-$1}"
  command -v "$command_name" >/dev/null 2>&1 \
    && pass "$label is installed" \
    || fail "$label is not installed"
}

bootstrap_hydration() {
  local brew_bin tool

  log "Bootstrapping hydration prerequisites"
  run_install "Bootstrap APT metadata" sudo env DEBIAN_FRONTEND=noninteractive apt-get update
  run_install "Bootstrap terminal tools" sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl gdebi-core git gnupg jq flatpak

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
  gum choose --height 12 --header "$prompt" --header.foreground 117 \
    --item.foreground 51 --cursor.foreground 51 --selected.foreground 10 --selected "$default" \
    --cursor-prefix '● ' "${options[@]}"
}

choose_many() {
  local prompt="$1" default_letters="$2" footer="$3"
  shift 3
  local options=("$@") header result="" selections index letter
  local letters=ABCDEFGHIJKLMNOPQRSTUVWXYZ
  default_letters="${default_letters^^}"
  default_letters="${default_letters//[[:space:]]/}"
  header="$prompt"
  [[ -n "$footer" ]] && header+=$'\n'"$footer"
  local -a selected_args=()
  for index in "${!options[@]}"; do
    letter="${letters:index:1}"
    [[ ",$default_letters," == *",$letter,"* ]] && selected_args+=(--selected "${options[$index]}")
  done
  selections="$(gum choose --no-limit --height 14 --header "$header" --header.foreground 117 \
    --item.foreground 51 --cursor.foreground 51 --selected.foreground 10 --cursor-prefix '● ' \
    --selected-prefix '✓ ' --unselected-prefix '○ ' "${selected_args[@]}" "${options[@]}")"
  [[ -z "$selections" ]] && { printf '%s' ''; return; }
  while IFS= read -r selection; do
    [[ "$selection" == None ]] && continue
    result+="${selection}|"
  done <<< "$selections"
  printf '%s' "$result"
}

selected() { [[ "|$1" == *"|$2|"* ]]; }
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

sudo -v

MODE="${1:-full}"
SELECTIONS_FILE="${2:-}"
case "$MODE" in
  gpu-integrated)
    sudo prime-select intel
    [[ "$(prime-select query)" == intel ]] || fatal "PRIME did not accept Intel mode"
    pass "Intel-only graphics selected; reboot to apply"
    exit 0
    ;;
  gpu-compute)
    sudo prime-select on-demand
    [[ "$(prime-select query)" == on-demand ]] || fatal "PRIME did not accept on-demand mode"
    pass "NVIDIA on-demand compute selected; reboot to apply"
    exit 0
    ;;
  full) ;;
  apply)
    [[ -n "$SELECTIONS_FILE" && -r "$SELECTIONS_FILE" ]] \
      || fatal "Usage: $0 apply <selection-manifest>"
    # The manifest is emitted by this script with `declare -p` after the user
    # confirms the Gum summary. It is the interface consumed by Go Task.
    source "$SELECTIONS_FILE"
    ;;
  *)
    fatal "Usage: $0 [full|gpu-integrated|gpu-compute]"
    ;;
esac

if [[ "$MODE" == full ]]; then
  bootstrap_hydration
  victuals_catalog_validate

  printf '\nGuided Ubuntu hydration\n'
  printf 'Bootstrap is validated. All remaining changes wait for your selections.\n'
  TERMINAL="$(choose_one 'Terminal emulator (Ubuntu GNOME includes Console; Omarchy Quattro status shown)' 1 \
  'Use Ubuntu Console [pre-installed]' \
  'Ghostty [Omarchy Quattro: optional]' \
  'Alacritty [Omarchy Quattro: optional]' \
  'Foot [Omarchy Quattro: bundled default]' \
  )"
FILE_MANAGERS="$(choose_many 'File managers (Files/Nautilus is pre-installed and always retained; select optional additions)' '' '' \
  'Carelo [dual-pane GUI; local-first]' \
  'Yazi [terminal; base plugins included]' \
  'Spacedrive [experimental v2 alpha; multi-device]')"
TERMINAL_EDITORS="$(choose_many 'Terminal editors (Fresh is mandatory; select optional additions)' '' \
  'Reminder: Nano, Vim, Micro, and Fresh are baseline editors.' \
  'Neovim [Omarchy Quattro default]')"
RESOURCE_MONITORS="$(choose_many 'System resource monitors (select optional additions)' '' \
  'btop is the baseline terminal monitor.' \
  'Mission Center [feature-rich GUI; GPU, sensors, and processes]')"
MULTIPLEXER="$(choose_one 'Terminal multiplexer (optional; None is the default)' 1 \
  None 'Tmux [recommended; Omarchy Quattro pre-installed]' \
  'Zellij [modern alternative]')"
BROWSERS="$(choose_many 'Browsers (choose one or several)' C '' \
  'Chrome: With all the Google tracking you never asked for, but with AI features.' \
  'Chromium: The smarter option.' \
  'Firefox: Classically installed. Not the Snap version.')"
TILER="$(choose_one 'GNOME tiling extension (not a DE/window-manager replacement; None is the default)' 1 \
  None 'O-Tiling [GNOME Shell extension; recommended]' \
  'Tiling Shell [GNOME Shell extension; alternative]' \
  'Simple Tiling [GNOME Shell extension; minimal fallback]' \
  'PaperWM [GNOME Shell extension; specialized alternative]')"
SPEECH_TO_TEXT="$(choose_one 'Offline speech-to-text dictation (one application; None is the default)' 1 \
  None 'Voxtype: Recommended. Omarchy Quattro Dictation.' \
  'Vocalinux: Low-resource VOSK option.' \
  'Speech Note: Mature offline desktop alternative.' \
  'Voquill: Polished cross-platform dictation. Account and trial flows.')"
AGENTS="$(choose_many 'AI command-line agents (choose one or several)' F '' \
  'OpenAI Codex [Omarchy Quattro prewired]' \
  'Claude Code [Omarchy Quattro prewired]' \
  'OpenCode [Omarchy Quattro prewired]' \
  'GitHub Copilot CLI [Omarchy Quattro prewired]' \
  'Gemini CLI [alternative]' None)"
OMARCHY_TOOLS="$(choose_many 'Ancillary tools (optional additions)' D '' \
  'Lazygit [pre-installed in Omarchy Quattro]' \
  'Gum [pre-installed in Omarchy Quattro]' None)"
LOCAL_MODELS="$(choose_many 'Local model runner (optional)' '' '' \
  'Ollama [local model runner and API]' None)"
CONNECTIVITY="$(choose_many 'Connectivity additions (optional)' '' '' \
  'NetworkManager OpenVPN plugin [GNOME VPN integration]' None)"
MAIL_CLIENTS="$(choose_many 'Mail clients (optional)' '' '' \
  'Thunderbird [Flatpak]' \
  'Betterbird [official Linux archive]' None)"
LOGITECH_DEVICE_MANAGER="$(choose_many 'Logitech and gaming-mouse management (optional)' '' '' \
  'OpenLogi: Local-first Logitech Options+ replacement.' \
  'Piper + ratbagd [supported gaming mice]' None)"
SYNERGY_SELECTION="$(choose_many 'Keyboard and mouse sharing (optional)' '' '' \
  'Synergy [share input across machines]' None)"
  DEV_TOOLCHAINS="$(choose_many 'Development toolchains (mise-managed; select optional additions)' '' \
  'Ubuntu system Python remains available; selected toolchains become your mise global defaults.' \
  'Node.js LTS [recommended for CLI tools]' \
  'Python [current stable]' \
  'Rust [stable]' \
  'Go [current stable]' \
  'Java [current stable]')"
  RESOURCE_MONITOR_SUMMARY='btop (baseline)'
  if [[ -n "$RESOURCE_MONITORS" ]]; then
    RESOURCE_MONITOR_SUMMARY+=", $(format_selections "$RESOURCE_MONITORS")"
  fi

  printf '\nSelected: terminal=%s; file-managers=%s; terminal-editors=%s; resource-monitors=%s; multiplexer=%s; browsers=%s; GNOME-tiling=%s; speech-to-text=%s; agents=%s; Omarchy-tools=%s; local-models=%s; connectivity=%s; mail=%s; Logitech-device-management=%s; Synergy=%s; dev-toolchains=%s\n' \
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

log "Removing Snap and preventing its return"
if command -v snap >/dev/null 2>&1; then
  mapfile -t snaps < <(timeout 30 snap list 2>/dev/null | awk 'NR > 1 {print $1}')
  for ((pass=1; pass<=4 && ${#snaps[@]} > 0; pass++)); do
    remaining=()
    for snap_name in "${snaps[@]}"; do
      if ! sudo timeout 180 snap remove --purge "$snap_name"; then
        remaining+=("$snap_name")
      fi
    done
    snaps=("${remaining[@]}")
  done
  if ((${#snaps[@]})); then
    warn "Snap packages still present before purge: ${snaps[*]}"
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
apt-cache policy snapd | grep -q 'Candidate: (none)' \
  && pass "snapd is pinned against reinstallation" \
  || fail "snapd still has an install candidate"

log "Installing the native application and development SBOM"
apt_packages=(
  ansilove aptitude bat btop
  ddgr desktop-file-utils eza fastfetch fd-find fuse3 fwupd fzf gh
  gnome-shell gnome-shell-extension-manager gnome-tweaks intel-microcode jq kanata
  micro mpv nala podman podman-compose ripgrep
  starship thermald timeshift unzip vim wakeonlan youtubedl-gui yt-dlp zoxide zsh
)
case "$TERMINAL" in
  'Ghostty [Omarchy Quattro: optional]') apt_packages+=(ghostty) ;;
  'Alacritty [Omarchy Quattro: optional]') apt_packages+=(alacritty) ;;
  'Foot [Omarchy Quattro: bundled default]') apt_packages+=(foot) ;;
esac
selected "$TERMINAL_EDITORS" 'Neovim [Omarchy Quattro default]' && apt_packages+=(neovim)
case "$MULTIPLEXER" in
  'Tmux [recommended; Omarchy Quattro pre-installed]') apt_packages+=(tmux) ;;
esac
if [[ "$SPEECH_TO_TEXT" == 'Voxtype: Recommended. Omarchy Quattro Dictation.' ]]; then
  apt_packages+=(wtype wl-clipboard libnotify-bin playerctl pipewire-alsa)
fi
selected "$OMARCHY_TOOLS" 'Lazygit [pre-installed in Omarchy Quattro]' && apt_packages+=(lazygit)
selected "$CONNECTIVITY" 'NetworkManager OpenVPN plugin [GNOME VPN integration]' && apt_packages+=(network-manager-openvpn)
selected "$LOGITECH_DEVICE_MANAGER" 'Piper + ratbagd [supported gaming mice]' && apt_packages+=(piper ratbagd)
selected "$SYNERGY_SELECTION" 'Synergy [share input across machines]' && apt_packages+=(synergy)
if selected "$AGENTS" 'OpenAI Codex [Omarchy Quattro prewired]' \
  || selected "$AGENTS" 'OpenCode [Omarchy Quattro prewired]' \
  || selected "$AGENTS" 'GitHub Copilot CLI [Omarchy Quattro prewired]' \
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
  'Voxtype: Recommended. Omarchy Quattro Dictation.')
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
if selected "$AGENTS" 'OpenAI Codex [Omarchy Quattro prewired]'; then
  run_install "OpenAI Codex" sudo npm install -g @openai/codex || vendor_failures+=(codex)
fi
if selected "$AGENTS" 'OpenCode [Omarchy Quattro prewired]'; then
  run_install "OpenCode" sudo npm install -g opencode-ai || vendor_failures+=(opencode)
fi
if selected "$AGENTS" 'GitHub Copilot CLI [Omarchy Quattro prewired]'; then
  run_install "GitHub Copilot CLI" sudo npm install -g @github/copilot || vendor_failures+=(copilot)
fi
if selected "$AGENTS" 'Gemini CLI [alternative]'; then
  run_install "Gemini CLI" sudo npm install -g @google/gemini-cli || vendor_failures+=(gemini-cli)
fi
if selected "$AGENTS" 'Claude Code [Omarchy Quattro prewired]'; then
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
selected "$TERMINAL_EDITORS" 'Neovim [Omarchy Quattro default]' && check_command nvim Neovim
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
  'Tmux [recommended; Omarchy Quattro pre-installed]') check_command tmux Tmux ;;
  'Zellij [modern alternative]') check_command zellij Zellij ;;
esac
selected "$AGENTS" 'OpenAI Codex [Omarchy Quattro prewired]' && check_command codex "OpenAI Codex"
selected "$AGENTS" 'Claude Code [Omarchy Quattro prewired]' && check_command claude "Claude Code"
selected "$AGENTS" 'OpenCode [Omarchy Quattro prewired]' && check_command opencode OpenCode
selected "$AGENTS" 'GitHub Copilot CLI [Omarchy Quattro prewired]' && check_command copilot "GitHub Copilot CLI"
selected "$AGENTS" 'Gemini CLI [alternative]' && check_command gemini "Gemini CLI"
selected "$OMARCHY_TOOLS" 'Lazygit [pre-installed in Omarchy Quattro]' && check_command lazygit Lazygit
selected "$OMARCHY_TOOLS" 'Gum [pre-installed in Omarchy Quattro]' && check_command gum Gum
check_command yt-dlp yt-dlp
selected "$MAIL_CLIENTS" 'Thunderbird [Flatpak]' \
  && sudo flatpak info org.mozilla.Thunderbird >/dev/null 2>&1 \
  && pass "Thunderbird is installed" \
  || true
selected "$MAIL_CLIENTS" 'Betterbird [official Linux archive]' && check_command betterbird Betterbird
case "$SPEECH_TO_TEXT" in
  'Voxtype: Recommended. Omarchy Quattro Dictation.')
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

log "Applying lightweight GNOME defaults for the current user"
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface enable-animations false
  gsettings set org.gnome.desktop.interface clock-show-weekday true
  gsettings set org.gnome.desktop.session idle-delay 300
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend'
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 900
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
  gsettings set org.gnome.desktop.privacy remember-recent-files false
  gsettings set org.gnome.desktop.search-providers disable-external true
fi
if command -v gnome-extensions >/dev/null 2>&1; then
  gnome-extensions disable ubuntu-dock@ubuntu.com 2>/dev/null || true
  gnome-extensions disable ding@rastersoft.com 2>/dev/null || true
fi
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
