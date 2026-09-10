#!/usr/bin/env bash

set -Eeuo pipefail

readonly START_TIME="$(date +%s)"
readonly REQUIREMENTS=(curl ca-certificates gum)
readonly APT_LOG="$(mktemp)"

cleanup() { rm -f -- "$APT_LOG"; }
trap cleanup EXIT

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

status() { printf '%b%s%b\n' "$BLUE" "$*" "$RESET"; }
pass() { printf '%bPASS: %s%b\n' "$GREEN" "$*" "$RESET"; }
fatal() { printf '%bFATAL: %s%b\n' "$RED" "$*" "$RESET" >&2; exit 1; }

requirement_present() {
  local requirement="$1"

  case "$requirement" in
    ca-certificates)
      dpkg-query -W -f='${db:Status-Abbrev}' ca-certificates 2>/dev/null \
        | grep -q '^ii '
      ;;
    curl|gum)
      command -v "$requirement" >/dev/null 2>&1
      ;;
    *)
      fatal "Unknown Victuals requirement: $requirement"
      ;;
  esac
}

elapsed() {
  printf '%ss' "$(( $(date +%s) - START_TIME ))"
}

status 'Checking Victuals requirements'
missing=()
for requirement in "${REQUIREMENTS[@]}"; do
  if requirement_present "$requirement"; then
    continue
  else
    missing+=("$requirement")
  fi
done

if ((${#missing[@]})); then
  status "Installing missing Victuals requirements: ${missing[*]}"
  install_requirements() {
    sudo apt update >"$APT_LOG" 2>&1 \
      && sudo apt install -y "${missing[@]}" >>"$APT_LOG" 2>&1
  }

  if command -v gum >/dev/null 2>&1; then
    gum spin --spinner line --title 'Installing Victuals requirements' -- \
      bash -c 'apt_log="$1"; shift; sudo apt update >"$apt_log" 2>&1 && sudo apt install -y "$@" >>"$apt_log" 2>&1' \
      _ "$APT_LOG" "${missing[@]}" \
      || fatal "Victuals requirement installation failed"
  else
    # Gum cannot render its own spinner until it has been installed.
    install_requirements || fatal "Victuals requirement installation failed"
  fi
fi

for requirement in "${REQUIREMENTS[@]}"; do
  requirement_present "$requirement" \
    || fatal "Victuals requirement is still unavailable: $requirement"
done

printf '\n'
pass "Victuals requirements are ready"
printf 'Requirements: %s\n' "${REQUIREMENTS[*]}"
printf 'Bootstrap duration: %s\n' "$(elapsed)"
printf '\n'

pass 'Ready for the first configuration prompt'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VICTUALS_CATALOG_DIR="${VICTUALS_CATALOG_DIR:-$SCRIPT_DIR/../../victuals/definitions}"
VICTUALS_CATALOG_DIR="$VICTUALS_CATALOG_DIR" exec bash "$SCRIPT_DIR/hydrate-ubuntu.sh"
