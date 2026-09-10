#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename -- "$0")"
REPO_DEB_URL="https://github.com/pop-os/system76-ubuntu-repo/releases/download/1.0.0/system76-ubuntu-repo_amd64.deb"
REPO_DEB_SHA256="ed5b538f90f7aaf715279c7fb7bc03dfc89750054be072feccee12c153091487"
PROFILE="battery"
SKIP_POWER_POLICY=false
NONINTERACTIVE=false
POWER_ONLY=false
NVIDIA_ONLY=false

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

REPORT_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-perf-pol"
REPORT_FILE="$REPORT_DIR/report.txt"
TEMP_DIR=""

log() { printf '\n%b==> %s%b\n' "$BLUE" "$*" "$RESET"; }
pass() { printf '%bPASS: %s%b\n' "$GREEN" "$*"; }
warn() { printf '%bWARN: %s%b\n' "$YELLOW" "$*" >&2; }
fatal() { printf '%bFATAL: %s%b\n' "$RED" "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Install and configure System76 Power for an Ubuntu laptop with Intel graphics
and an NVIDIA compute GPU.

Options:
  --profile PROFILE       battery (default), balanced, or performance
  --skip-power-policy     Do not install or configure System76 Power
  --nvidia-optimize-only Alias for --skip-power-policy
  --power-only            Configure only the System76 power profile
  --nvidia-only           Configure only System76 compute graphics mode
  --non-interactive       Use --profile without prompting
  -h, --help              Show this help

The default configuration is System76 compute graphics mode plus the battery
profile. Graphics-mode changes require a reboot; this script never reboots.
EOF
}

cleanup() {
  [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT

require_ubuntu() {
  [[ -r /etc/os-release ]] || fatal "Cannot identify the operating system"
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == ubuntu ]] || fatal "This script supports Ubuntu only"
  [[ "$(dpkg --print-architecture)" == amd64 ]] || fatal "Only amd64 is supported by the pinned repository package"
}

parse_args() {
  while (($#)); do
    case "$1" in
      --profile)
        (($# >= 2)) || fatal "--profile requires a value"
        PROFILE="$2"
        shift 2
        ;;
      --skip-power-policy|--nvidia-optimize-only)
        SKIP_POWER_POLICY=true
        shift
        ;;
      --power-only)
        POWER_ONLY=true
        shift
        ;;
      --nvidia-only)
        NVIDIA_ONLY=true
        shift
        ;;
      --non-interactive)
        NONINTERACTIVE=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fatal "Unknown option: $1"
        ;;
    esac
  done

  case "$PROFILE" in
    battery|balanced|performance) ;;
    *) fatal "Unsupported profile: $PROFILE" ;;
  esac
}

select_profile() {
  local selected
  [[ "$SKIP_POWER_POLICY" == true || "$NONINTERACTIVE" == true ]] && return
  command -v gum >/dev/null 2>&1 || return
  [[ -t 0 && -t 1 ]] || return
  selected="$(gum choose --header 'Select the System76 Power profile' \
    --selected "$PROFILE" battery balanced performance)"
  [[ -n "$selected" ]] && PROFILE="$selected"
}

install_gum() {
  if ! command -v gum >/dev/null 2>&1; then
    log "Installing Gum"
    sudo install -d -m 0755 /etc/apt/keyrings
    curl -fsSL --retry 3 https://repo.charm.sh/apt/gpg.key \
      | sudo gpg --dearmor --yes -o /etc/apt/keyrings/charm.gpg
    printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *' \
      | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null
    sudo apt-get update
  fi
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y gum mesa-utils
  command -v gum >/dev/null 2>&1 || fatal "Gum installation did not produce the gum command"
  pass "Gum is installed"
}

install_system76_power() {
  local deb_file actual_sha256
  TEMP_DIR="$(mktemp -d -t perf-pol.XXXXXX)"
  deb_file="$TEMP_DIR/system76-ubuntu-repo_amd64.deb"

  log "Installing the pinned System76 Ubuntu repository package"
  curl -fL --retry 3 "$REPO_DEB_URL" -o "$deb_file"
  actual_sha256="$(sha256sum "$deb_file" | awk '{print $1}')"
  [[ "$actual_sha256" == "$REPO_DEB_SHA256" ]] \
    || fatal "System76 repository package checksum mismatch"
  sudo apt-get install -y "$deb_file"

  log "Refreshing APT metadata"
  sudo apt-get update

  log "Installing System76 Power"
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y system76-power
  command -v system76-power >/dev/null 2>&1 || fatal "system76-power is not installed"
  systemctl is-active --quiet com.system76.PowerDaemon.service \
    || fatal "System76 Power daemon is not active"
  pass "System76 Power is installed and active"
}

configure_power_profile() {
  log "Configuring System76 $PROFILE profile"
  sudo system76-power profile "$PROFILE"
  pass "System76 profile set to $PROFILE"
}

configure_nvidia_compute() {
  log "Configuring System76 compute graphics mode"
  sudo system76-power graphics compute
  pass "System76 graphics mode set to compute"
}

validate_nvidia_path() {
  local graphics profile_output nvidia_output display_active
  log "Validating Intel desktop and NVIDIA compute path"

  graphics="$(system76-power graphics 2>/dev/null || true)"
  [[ "$SKIP_POWER_POLICY" == true || "$graphics" == compute ]] \
    && pass "System76 graphics mode: ${graphics:-not managed by System76}" \
    || fatal "System76 graphics mode is '$graphics', expected compute"

  if [[ "$SKIP_POWER_POLICY" == false && "$NVIDIA_ONLY" == false ]]; then
    profile_output="$(system76-power profile 2>/dev/null || true)"
    grep -Fq "Power Profile: ${PROFILE^}" <<<"$profile_output" \
      && pass "System76 profile: $PROFILE" \
      || fatal "System76 profile did not report ${PROFILE^}"
  fi

  if command -v glxinfo >/dev/null 2>&1; then
    glxinfo_output="$(glxinfo -B 2>/dev/null || true)"
    grep -Fq 'OpenGL vendor string: Intel' <<<"$glxinfo_output" \
      && pass "Intel is the active OpenGL renderer" \
      || fatal "Intel is not the active OpenGL renderer"
  else
    warn "glxinfo is not installed; skipped desktop-renderer validation"
  fi

  lsmod | grep -q '^nouveau ' \
    && fatal "nouveau is loaded" \
    || pass "nouveau is not loaded"

  command -v nvidia-smi >/dev/null 2>&1 || fatal "nvidia-smi is not installed"
  nvidia_output="$(nvidia-smi 2>/dev/null || true)"
  display_active="$(nvidia-smi --query-gpu=display_active --format=csv,noheader 2>/dev/null || true)"
  [[ "$display_active" == Disabled ]] \
    && pass "NVIDIA is not attached to a display" \
    || warn "NVIDIA display state was not reported as off"
  grep -Fq 'No running processes found' <<<"$nvidia_output" \
    && pass "NVIDIA has no active clients" \
    || warn "NVIDIA reports one or more active clients"

  printf '%s\n' "$nvidia_output" | tee -a "$REPORT_FILE" >/dev/null
}

main() {
  parse_args "$@"
  require_ubuntu
  mkdir -p "$REPORT_DIR"
  exec > >(tee "$REPORT_FILE") 2>&1

  log "Starting $SCRIPT_NAME"
  printf 'UTC timestamp: %s\n' "$(date --iso-8601=seconds --utc)"
  printf 'Profile: %s\n' "$PROFILE"
  printf 'Skip power policy: %s\n' "$SKIP_POWER_POLICY"

  if [[ "$SKIP_POWER_POLICY" == false ]]; then
    sudo -v
    install_gum
    select_profile
    install_system76_power
    if [[ "$NVIDIA_ONLY" == true ]]; then
      configure_nvidia_compute
      next_step="Reboot to apply compute graphics mode, then re-run validation"
      printf '%bNEXT STEP: %s%b\n' "$YELLOW" "$next_step" "$RESET"
    else
      configure_power_profile
    fi
  else
    log "Skipping System76 Power installation and policy changes"
  fi

  [[ "$POWER_ONLY" == true ]] || validate_nvidia_path
  pass "Performance policy configuration finished; no reboot was initiated"
}

main "$@"
