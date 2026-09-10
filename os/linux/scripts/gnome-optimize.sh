#!/usr/bin/env bash

set -Eeuo pipefail

DRY_RUN=false
SELECT_ALL=false
while (($#)); do
  case "$1" in
    --dry-run|--plan-mode)
      DRY_RUN=true
      ;;
    --all|--non-interactive)
      SELECT_ALL=true
      ;;
    --help|-h)
      cat <<EOF
Usage: $0 [options]

Options:
  --dry-run           Show and describe the selected policy without changing GNOME.
  --plan-mode         Alias for --dry-run.
  --all               Select every available optimization without prompting.
  --non-interactive   Alias for --all.
EOF
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

fatal() {
  printf '%bFATAL: %s%b\n' "$RED" "$*" "$RESET" >&2
  exit 1
}

pass() { printf '%bPASS: %s%b\n' "$GREEN" "$*" "$RESET"; }
warn() { printf '%bWARN: %s%b\n' "$YELLOW" "$*" "$RESET" >&2; }
log() { printf '\n%b==> %s%b\n' "$BLUE" "$*" "$RESET"; }

trap 'printf "\n%bGNOME optimization cancelled. No further changes will run.%b\n" "$YELLOW" "$RESET"; exit 130' INT TERM

command -v gsettings >/dev/null 2>&1 || fatal 'gsettings is required'
command -v gum >/dev/null 2>&1 || fatal 'Gum is required; install it before running this script'

terminal_width() {
  local width="${COLUMNS:-}"
  [[ "$width" =~ ^[0-9]+$ && "$width" -ge 32 ]] || width="$(tput cols 2>/dev/null || printf '80')"
  [[ "$width" =~ ^[0-9]+$ && "$width" -ge 32 ]] || width=80
  printf '%s' "$((width - 2))"
}

header() {
  local title_line description_line header_text
  printf -v title_line '\033[1;38;5;117m%s\033[0m' 'GNOME Optimization'
  printf -v description_line '\033[38;5;250m%s\033[0m' \
    'Choose the performance, power, and desktop-behavior changes to apply.'
  header_text="${title_line}"$'\n'"${description_line}"
  gum style --border rounded --border-foreground 117 --width "$(terminal_width)" \
    --padding '0 1' "$header_text"
}

options=(
  $'\033[1mDisable animations\033[0m       \033[38;5;250mPros: less compositor work and snappier transitions. Cons: less visual feedback.\033[0m|animations'
  $'\033[1mDisable recent files\033[0m     \033[38;5;250mPros: less recent-file bookkeeping. Cons: GNOME apps lose their recent-file list.\033[0m|recent-files'
  $'\033[1mDisable external search\033[0m  \033[38;5;250mPros: fewer search-provider processes and less background work. Cons: external providers disappear from overview search.\033[0m|external-search'
  $'\033[1mDisable Ubuntu Dock\033[0m      \033[38;5;250mPros: removes an extension from the Shell session. Cons: the dock is no longer available.\033[0m|ubuntu-dock'
  $'\033[1mDisable desktop icons\033[0m    \033[38;5;250mPros: removes desktop-icon extension work. Cons: desktop files and folders are no longer shown on the desktop.\033[0m|desktop-icons'
  $'\033[1mSet idle timeout to 5m\033[0m    \033[38;5;250mPros: reduces unattended active time and saves power. Cons: shorter idle timeout may interrupt passive viewing.\033[0m|idle-delay'
  $'\033[1mSuspend battery after 15m\033[0m \033[38;5;250mPros: protects battery and reduces idle drain. Cons: long-running battery tasks may be suspended.\033[0m|battery-suspend'
  $'\033[1mDo nothing on AC idle\033[0m    \033[38;5;250mPros: avoids unwanted suspension while plugged in. Cons: an unattended plugged-in session stays awake.\033[0m|ac-idle'
  $'\033[1mShow weekday in clock\033[0m    \033[38;5;250mPros: improves at-a-glance context. Cons: uses a little more panel space; no performance gain.\033[0m|clock-weekday'
)

selected_ids=''
if [[ "$SELECT_ALL" == true ]]; then
  for option in "${options[@]}"; do
    selected_ids+="${option##*|}|"
  done
else
  selections="$(gum choose --no-limit --height 16 --header "$(header)" \
    --item.foreground 250 --cursor.foreground 51 --selected.foreground 10 \
    --cursor-prefix '▸ ' --selected-prefix '✓ ' --unselected-prefix '○ ' \
    --padding '0 1' --label-delimiter '|' --selected '*' "${options[@]}")"
  while IFS= read -r selection; do
    [[ -n "$selection" ]] && selected_ids+="$selection|"
  done <<< "$selections"
fi

selected() { [[ "|$selected_ids" == *"|$1|"* ]]; }

log 'Selected GNOME policy'
for option in "${options[@]}"; do
  value="${option##*|}"
  selected "$value" && printf '  • %s\n' "$value"
done

apply_gsettings() {
  local schema="$1" key="$2" value="$3" label="$4"
  if [[ "$DRY_RUN" == true ]]; then
    printf '%bPLAN: %s → %s %s %s%b\n' "$YELLOW" "$label" "$schema" "$key" "$value" "$RESET"
  else
    gsettings set "$schema" "$key" "$value"
    pass "$label"
  fi
}

apply_extension() {
  local uuid="$1" label="$2"
  if ! command -v gnome-extensions >/dev/null 2>&1; then
    warn "$label skipped: gnome-extensions is unavailable"
    return 0
  fi
  if [[ "$DRY_RUN" == true ]]; then
    printf '%bPLAN: Disable %s (%s)%b\n' "$YELLOW" "$label" "$uuid" "$RESET"
  else
    gnome-extensions disable "$uuid" 2>/dev/null || true
    pass "$label disabled"
  fi
}

if selected animations; then
  apply_gsettings org.gnome.desktop.interface enable-animations false 'Disable interface animations'
fi
if selected recent-files; then
  apply_gsettings org.gnome.desktop.privacy remember-recent-files false 'Disable recent-file tracking'
fi
if selected external-search; then
  apply_gsettings org.gnome.desktop.search-providers disable-external true 'Disable external search providers'
fi
if selected ubuntu-dock; then
  apply_extension ubuntu-dock@ubuntu.com 'Ubuntu Dock extension'
fi
if selected desktop-icons; then
  apply_extension ding@rastersoft.com 'Desktop Icons extension'
fi
if selected idle-delay; then
  apply_gsettings org.gnome.desktop.session idle-delay 'uint32 300' 'Set GNOME idle delay to 5 minutes'
fi
if selected battery-suspend; then
  apply_gsettings org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type suspend 'Set battery idle action to suspend'
  apply_gsettings org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 'uint32 900' 'Set battery suspend timeout to 15 minutes'
fi
if selected ac-idle; then
  apply_gsettings org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing 'Disable AC idle action'
fi
if selected clock-weekday; then
  apply_gsettings org.gnome.desktop.interface clock-show-weekday true 'Show weekday in the clock'
fi

if [[ "$DRY_RUN" == true ]]; then
  pass 'Dry run complete; GNOME was not changed'
else
  pass 'GNOME optimization policy applied'
fi
