# Ubuntu 26.04 Hydration Design

This note preserves the requirements and decisions recovered from a local Codex
session on 2026-08-29. It is the design record for the guided Ubuntu hydration
workflow; it is not a claim that every installation path has completed an
end-to-end privileged test.

## Goal

Hydrate a freshly staged Ubuntu 26.04 development workstation with no more than
two explicit setup commands:

```bash
./install/install-task.sh
task hydrate
```

Running plain `task` must only list available actions. Go Task uses
`task hydrate`, not `task -hydrate`.

The administrator is expected to run the customary Ubuntu update first and to
make this repository available locally, such as from a USB drive. Application
and system provisioning are the priority; dotfile linking is not required for
the first complete hydration pass.

## Interaction model

The hydrator collects every preference before making application or desktop
changes, displays a summary, and gives the user a final chance to cancel. Keep
each category small, curated, and opinionated rather than presenting an
exhaustive catalog.

Before the first preference question, hydration installs and validates Gum from
Charm's signed Ubuntu repository and go-task using Task's official user-local
installer. Gum then renders the questionnaire for Ptyxis and other ANSI-color
terminals: headers, choices, and the cursor are light blue/cyan, while selected
and default entries use green checkmarks. The only system changes
before the questionnaire are these two menu prerequisites.

Current choices are:

- Terminal: use Ubuntu Console (the pre-installed default), or opt into
  Ghostty, Alacritty, or Foot. The prompt notes that Omarchy Quattro makes Foot
  its bundled default and offers Ghostty and Alacritty as optional terminals.
- File managers: Files (Nautilus) is pre-installed by Ubuntu and Omarchy
  Quattro and is always retained. The user may additionally select any
  combination of Carelo (a dual-pane local-first GUI), Yazi (a terminal file
  manager with the curated Git, smart-enter, jump-to-char, toggle-pane, diff,
  and smart-paste plugins), and Spacedrive v2 alpha (an experimental
  multi-device file library). The prompt defaults to no additions.
- Terminal editors: Nano, Vim, and Micro are baseline editors and are always
  available. The user may additionally select Fresh (a modern terminal IDE)
  and Neovim (Omarchy Quattro's default editor). The prompt defaults to no
  additions and reminds the user of the baseline editors at its bottom.
- System resource monitors: GNOME System Monitor and btop are baseline tools
  and always available. The user may additionally select Mission Center, a
  feature-rich GTK4/libadwaita GUI with GPU, sensor, and process views. The
  prompt defaults to no additions.
- Terminal multiplexer: none (default), Tmux (recommended and pre-installed by
  Omarchy Quattro), or Zellij (modern alternative).
- Browsers: Chrome, Chromium, Firefox, or a combination. Firefox is the
  recovered default and is installed from Flathub rather than Snap. Chrome
  uses Google's official deb; Chromium uses Flathub. Chrome and Chromium
  receive upgrade-safe user launchers that select Wayland in a Wayland session,
  use Wayland window decorations, and enable touchpad swipe history navigation.
  Chrome's launcher additionally enables the non-development GLIC feature set.
- GNOME tiling (mutually exclusive): none (default), O-Tiling (recommended),
  Tiling Shell (alternative), Simple Tiling (minimal fallback), or PaperWM
  (specialized alternative). Every named choice is a GNOME Shell extension.
  This category deliberately excludes desktop environments and
  standalone/compositing window managers such as Niri and i3; GNOME remains
  the session and window manager.
- Offline speech-to-text dictation (mutually exclusive): none (default),
  Voxtype (recommended and available through Omarchy Quattro's Dictation
  installer), Vocalinux (the lower-resource VOSK option), Speech Note (the
  mature offline desktop alternative), or Voquill (the polished
  cross-platform option with account and trial flows). Each application retains
  its own model choice and first-run setup after hydration.
- AI command-line agents: OpenAI Codex, Claude Code, OpenCode, GitHub Copilot
  CLI, Gemini CLI, or none. More than one agent may be selected. The first four
  are Quattro's prewired lazy launchers; hydration installs the selected client
  rather than reproducing Omarchy's launcher system.
- Mandatory shell baseline: Git, Fzf, Eza, Zoxide, Bat, Ripgrep, Fd,
  Fastfetch, Leaf, Micro, and Starship install without a prompt because the tracked
  Linux Bash/Zsh profiles invoke them during normal shell use. Ubuntu's
  `batcat` and `fdfind` packages receive user-local `bat` and `fd` command
  shims, respectively; any unavailable native package falls back to Linuxbrew
  and every required command is validated before optional selections continue.
- Ancillary tools: optionally install Lazygit (a terminal UI for Git), yt-dlp
  (a resilient media downloader), and Gum (a helper for pleasant interactive
  shell scripts). Each is part of Quattro's current base package manifest and
  is available from the enabled Ubuntu repositories.
- Logitech device management: none (default), or OpenLogi. OpenLogi is a
  native local-first Logitech Options+ replacement, kept separate from the
  generic CLI/TUI and AI-agent categories because it configures HID++ hardware.
- Development toolchains are collected last: the script has already
  bootstrapped mise, then offers optional global mise toolchains for Node.js
  LTS, current Python, stable Rust, current Go, and current Java. Ubuntu's
  system Python remains available and is not replaced. The prompt defaults to
  no additions.

The baseline system and development SBOM installs without individual prompts.
Future preference-sensitive categories should follow the same limited-choice
pattern.

### File-manager installation details

Carelo, Yazi, and Spacedrive are installed per-user so the optional additions
do not require a third-party APT repository or Snap. Carelo's official AppImage
is extracted under `~/.local/opt/carelo/<release>` and must be launched through
its `AppRun` wrapper; invoking the internal binary bypasses its bundled runtime
setup. Yazi's official GNU/Linux archive supplies version-matched `yazi` and
`ya` binaries, then `ya pkg add` pins the curated base plugin set. Spacedrive
must resolve the current v2 prerelease from the releases API rather than the
GitHub `releases/latest` endpoint, which currently points to the obsolete v1
series; its official `.deb` is safely extracted under
`~/.local/opt/spacedrive/<release>` without invoking `dpkg` as root.

## System policy

### Packages and Snap

- Use the repository package precedence: APT/deb, AppImage, Linuxbrew, Flatpak,
  mise, pnpm, npm, then pip.
- When the target Ubuntu desktop already supplies a capable tool, retain it as
  the explicit default and install alternatives only when selected. The only
  exception is the Quattro CLI/TUI category, whose default is no additions.
- Remove all installed Snap applications, purge `snapd`, and install an APT pin
  preventing its return.
- Replace Snap-transition desktop applications through a preferred non-Snap
  source. Firefox and Chromium currently use Flathub when selected; Chrome uses
  Google's official deb. Chrome and Chromium launch from per-user wrappers so
  package or Flatpak updates cannot overwrite their session-aware Wayland and
  touchpad-history-navigation settings. The gesture setting is Chromium's
  `TouchpadOverscrollHistoryNavigation` feature; it enables horizontal
  two-finger back and forward navigation, not arbitrary right-button mouse
  drawing gestures.
- Install the common application/development SBOM plus Code Insiders,
  Tailscale, Ollama, and the selected applications and agents.
- Before optional application installation, install the baseline artifact and
  development managers: APT/dpkg plus gdebi for `.deb` files, FUSE and desktop
  registration helpers for AppImages, Flatpak with Flathub, Linuxbrew, and
  mise. Each reports installation progress and is validated before the later
  selected applications depend on it.

### Power and graphics

The target machine observed during design was a Dell workstation with an Intel
UHD P630 and NVIDIA Quadro T2000 Max-Q. Its NVIDIA driver reported runtime D3
power-down as unsupported and retained active VRAM in PRIME on-demand mode.

Therefore:

- Default to Intel-only PRIME mode for maximum battery life.
- Provide a separate `task hydrate:gpu-compute` action to select NVIDIA
  on-demand mode for local-model/CUDA work.
- Provide `task hydrate:gpu-integrated` to return to battery mode.
- Both mode changes require a reboot.
- Use TLP plus `thermald`, and disable the conflicting GNOME power-profiles
  daemon.
- Do not make System76 Power the default. It was rejected for this non-System76
  Dell and because Ubuntu releases after 24.04 were not considered sufficiently
  validated during the original investigation.

The aspirational unplugged runtime is 8 hours minimum, with 9-12 hours as a
tuning target. That target is hardware-, battery-, workload-, and display-
dependent and must be measured rather than reported as guaranteed.

### Desktop and input

- Keep GNOME installed as the safe session and login fallback.
- Use a GNOME Shell extension rather than installing a second window manager or
  compositor. Disable the other managed tiling extensions when applying a
  selection so multiple tiling engines cannot conflict.
- Always install GNOME's Extensions controls, Extension Manager, and GNOME
  Tweaks as baseline applications. They remain available even when the tiling
  selection is None.
- Match the extension download to the installed GNOME Shell major version and
  require a logout/login after installing one under Wayland.
- Always finish hydration by asking the user to log out and back in. This
  refreshes GNOME's application registry and activates user-profile changes
  made for Linuxbrew and mise, even when no GNOME extension was selected.
- Reduce GNOME overhead by disabling animations, the Ubuntu Dock, desktop icons,
  external search providers, and unnecessary recent-file tracking.
- Configure practical idle and suspend behavior.
- Install Kanata as a privileged system service so keyboard behavior works at
  the login/session boundary and has the required input-device permissions.
  Hydration invokes `tasks/kanata.yml` only for the tracked user keymap symlink
  at `~/.config/kanata/kanata.kbd`; it never enables a second user-systemd
  Kanata service.
- Zsh and dotfile deployment are optional and must not impede the core hydration
  goal.

## Validation contract

Every provisioning script must perform some completion validation, even if the
check is basic. Output must use consistent color-coded status:

- Blue: phase/progress heading.
- Green: passed validation.
- Yellow: warning or optional failure.
- Red: required validation failure or fatal error.

Every application install must also announce `INSTALLING: <name>` before work
begins and `PASS: Installed: <name>` after success. This applies to the native
APT batch, each Flatpak, vendor release, selected file manager, and AI agent.
Carelo additionally prints an immediate instruction to log out and back in
before launching it from the GNOME Applications launcher.

Required failures must produce a nonzero exit. The hydration report is written
to:

```text
~/.local/state/dotfiles-hydration/report.txt
```

At minimum, validate package installation/integrity, Snap removal and pinning,
selected applications, TLP and thermald, PRIME mode, GNOME settings, and the
Kanata configuration/service.

## Safety and privilege model

- Do not run Codex itself with `sudo`.
- The Task installer should install for the user without root where practical.
- Hydration should request `sudo` only for the system operations that need it.
- Optional user-local file managers install after confirmation and register
  launchers under `~/.local/share/applications`.
- Collect choices and confirmation before destructive changes.
- Temporary vendor installers must be downloaded to a temporary directory and
  removed afterward.

## Implementation map

- `Taskfile.yml`: public `hydrate` and compatibility `install-all` entry points.
- `tasks/hydrate.yml`: Ubuntu hydration and GPU-mode tasks.
- `os/linux/scripts/hydrate-ubuntu.sh`: guided provisioning and validation.
- `install/install-task.sh`: Go Task bootstrap.
- `os/linux/config/apt/no-snap.pref`: Snap prevention policy.
- `os/linux/config/tlp/50-dotfiles-workstation.conf`: workstation power policy.
- `os/linux/config/systemd/system/kanata.service`: privileged Kanata service.

## Recovered status

The guided implementation exists in the working tree but was uncommitted when
this note was written. Shell syntax and Ubuntu repository availability had been
checked in the prior session. A full privileged hydration was requested, but it
could not be completed through that session because `sudo` required an
interactive credential. The destructive end-to-end run therefore remains to be
performed from the administrator's terminal; do not describe it as verified
until the resulting report and service state have been reviewed.
