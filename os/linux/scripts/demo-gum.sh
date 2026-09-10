#!/usr/bin/env bash

set -Eeuo pipefail

if ! command -v gum >/dev/null 2>&1; then
  printf 'gum is not installed or is not on PATH.\n' >&2
  exit 127
fi

pause() {
  printf '\n'
  gum style --foreground 245 'Press Enter to continue.'
  read -r
}

section() {
  clear
  gum style \
    --border rounded \
    --border-foreground 99 \
    --padding '0 1' \
    --margin '1 0' \
    --bold \
    "$1"
}

section 'Gum capability tour'
gum style --foreground 252 \
  'This script demonstrates Gum controls one at a time.' \
  'Nothing is installed or changed by the tour.'
pause

section '1. gum choose — single selection'
choice="$(gum choose \
  --header 'Choose a favorite installation phase:' \
  'Bootstrap' 'Applications' 'Configuration' 'Validation')"
gum style --foreground 42 "Selected: $choice"
pause

section '2. gum choose --no-limit — multiple selections'
choices="$(gum choose --no-limit \
  --header 'Select the capabilities to include:' \
  'APT' 'Flatpak' 'Linuxbrew' 'Go Task' 'Chrome extensions')"
gum style --foreground 42 'Selected:'
printf '%s\n' "$choices" | gum style --foreground 252 --padding '0 2'
pause

section '3. gum filter — searchable selection'
filtered="$(printf '%s\n' \
  'ca-certificates' 'git' 'curl' 'gum' 'flatpak' 'linuxbrew' 'go-task' \
  | gum filter --header 'Type to filter a package:')"
gum style --foreground 42 "Filtered result: $filtered"
pause

section '4. gum input — one-line text input'
name="$(gum input --placeholder 'Enter a label')"
gum style --foreground 42 "You entered: ${name:-<empty>}"
pause

section '5. gum write — multiline text input'
notes="$(gum write --placeholder 'Write a short note, then press Ctrl+D')"
gum style --foreground 42 'Your note:'
printf '%s\n' "$notes" | gum style --foreground 252 --padding '0 2'
pause

section '6. gum confirm — yes/no confirmation'
if gum confirm 'Continue the capability tour?'; then
  gum style --foreground 42 'Confirmed.'
else
  gum style --foreground 214 'Cancelled.'
  exit 0
fi
pause

section '7. gum style — formatted output'
gum style \
  --border double \
  --border-foreground 212 \
  --foreground 255 \
  --background 57 \
  --padding '1 2' \
  --margin '0 2' \
  'This is a styled status card.' \
  'It can show the current hydration phase.'
pause

section '8. gum table — structured output'
printf '%s\n' \
  'Phase,Status,Elapsed' \
  'Bootstrap,passed,12s' \
  'Applications,running,01m 08s' \
  'Validation,pending,—' \
  | gum table --border rounded
pause

section '9. gum spin — run a command with a spinner'
gum style --foreground 252 \
  'gum spin runs a command, displays an animated spinner while it runs,' \
  'and returns the command exit status when it finishes.'
printf '\n'
gum spin --spinner dot --title 'Simulating a five-second task...' -- bash -c 'sleep 5'
gum style --foreground 42 'The simulated task completed.'
pause

section '10. gum spin --show-output — spinner plus command output'
gum style --foreground 252 \
  'Use --show-output when the command output is useful during the spinner.'
printf '\n'
gum spin --spinner pulse --show-output --title 'Streaming sample output...' -- bash -c \
  'for step in 1 2 3; do printf "working step %s\\n" "$step"; sleep 1; done'
gum style --foreground 42 'The streamed task completed.'
pause

section 'Tour complete'
gum style --foreground 42 \
  'You have seen selection, search, input, confirmation, styling, tables, and spinners.'
