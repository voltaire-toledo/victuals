# Ubuntu hydration software bill of materials

This is the authoritative inventory for
[`hydrate-ubuntu.sh`](../scripts/hydrate-ubuntu.sh). It records packages and
applications the script can install, not every transitive dependency resolved
by APT, Flatpak, Linuxbrew, or a vendor package. APT packages are installed only
when available from the enabled Ubuntu repositories; the mandatory shell tools
fall back to Linuxbrew when necessary. Snap is deliberately absent.

## Bootstrap phase (`hydrate-ubuntu.sh`)

On a fresh Ubuntu host, start the one terminal-only hydrator directly because
Go Task does not exist yet:

```bash
bash os/linux/scripts/hydrate-ubuntu.sh
```

Its bootstrap phase installs and validates the execution prerequisites below,
then continues in the same process so its exported `PATH` is available to child
Task commands. Git is included so
the checkout can be updated or acquired from a terminal; when this repository
was cloned normally, it is already present. GDebi is supplied as a manual,
dependency-aware local-`.deb` option; hydration itself uses `apt-get install
./package.deb` so that the install is non-interactive and auditable.

| Component | Purpose | Install Method |
|---|---|---|
| Git | Repository acquisition and source control. | APT |
| Go Task | Runs the OS-agnostic installation/configuration tasks after bootstrap. | Official Task installer, `~/.local/bin` |
| Gum | Presents terminal-only hydration prompts. | Charm APT repository |
| Flatpak and Flathub | Desktop-app engine and its configured remote. | APT, then `flatpak remote-add` |
| Linuxbrew | User-space package manager for supported shell tooling. | Official installer |
| GDebi | Manual local-`.deb` inspection/install fallback. | APT |

## Support packages

These are intentional bootstrap tools or explicit prerequisites, listed in the
order hydration installs them. Transitive libraries are deliberately omitted.

| Package | Description | Tools included | Install Method |
|---|---|---|---|
| `ca-certificates` | Trust store required before adding the Gum repository and downloading vendor installers. | System CA bundle. | APT, pre-hydration bootstrap |
| `curl` | Transfer client used by the hydrator for repositories and vendor installers. | `curl`. | APT, pre-hydration bootstrap |
| `gnupg` | Dearmors the Gum repository signing key. | `gpg`. | APT, pre-hydration bootstrap |
| `desktop-file-utils` | Validates and refreshes launchers created by hydration. | `desktop-file-validate`, `update-desktop-database`. | APT, native baseline |
| `fuse3` | Explicit runtime prerequisite for the AppImage installation paths. | `fusermount3`. | APT, native baseline |
| `gnome-shell` | GNOME-extension host used by the tiling installer. | `gnome-shell`, `gnome-extensions`. | APT, native baseline |
| `jq` | Parses vendor release metadata. | `jq`. | APT, native baseline |
| `unzip` | Extracts the Yazi release archive. | `unzip`. | APT, native baseline |
| `wtype` | Wayland virtual keyboard input required by selected Voxtype. | `wtype`. | APT, only when Voxtype is selected |
| `wl-clipboard` | Clipboard support required by selected Voxtype. | `wl-copy`, `wl-paste`. | APT, only when Voxtype is selected |
| `libnotify-bin` | Notification command required by selected Voxtype. | `notify-send`. | APT, only when Voxtype is selected |
| `playerctl` | Media-control command required by selected Voxtype. | `playerctl`. | APT, only when Voxtype is selected |
| `pipewire-alsa` | Explicit ALSA-to-PipeWire prerequisite for selected Voxtype. | ALSA PipeWire plugin. | APT, only when Voxtype is selected |

## Power management and graphics policy

| Component or policy | Hydration action | Install Method |
|---|---|---|
| Intel microcode | Installs Ubuntu's Intel microcode package in the native baseline. | APT |
| TLP and thermald | Installs TLP and the thermal daemon, writes `50-dotfiles-workstation.conf`, enables both services, starts TLP, and validates them. It deliberately does **not** run hardware probing or apply PowerTOP tunables. | APT and systemctl |
| `tlp-rdw` | TLP's optional Radio Device Wizard. It is not installed. | Not installed |
| GNOME power profiles | Disables and masks `power-profiles-daemon`, because the tracked TLP policy owns the selected power policy. | systemctl |
| `lm-sensors` and PowerTOP | These require machine-specific review: `sensors-detect` may load or persist kernel modules, while PowerTOP's calibration/tunables require a measured workload and explicit acceptance. Neither is installed by hydration. | Not installed |
| NVIDIA driver support | On NVIDIA hardware, invokes `ubuntu-drivers install`, then selects Intel-only mode for battery life. | Ubuntu Drivers and pre-installed `prime-select` |
| PRIME graphics mode | Uses the already present NVIDIA PRIME tooling; no `nvidia-prime` package is installed by hydration. | `prime-select` |

## Mandatory apps

These applications install on every full hydration. “Mandatory” means the
hydrator attempts installation; a missing package in the enabled repositories
is reported as a validation failure or warning according to its installation
path.

| Category | Application | Type | Install Method | Short Description | Post-install setup / plugins / customizations |
|---|---|---|---|---|
| Connectivity | Tailscale | CLI, Service | Vendor installer | Mesh-VPN client and background daemon. | Installed and validated; account login/network join remains user-directed. |
| Containers | Podman | CLI, Service | APT | Daemonless container engine. | The user Podman socket is enabled. |
| Containers | Podman Compose | CLI | APT | Compose-compatible Podman workflow. | No configuration. |
| Containers | Podman Desktop | GUI | Flatpak | Desktop UI for managing Podman workloads. | No connection or container is created. |
| Desktop | GNOME Extension Manager | GUI | APT | Manage GNOME Shell extensions. | Selected tiler is installed/enabled through `gnome-extensions`; other managed tilers are disabled. |
| Desktop | GNOME Tweaks | GUI | APT | Advanced GNOME preferences. | GNOME policy is applied separately by the hydrator. |
| Development | GitHub CLI | CLI | APT | GitHub workflow client (`gh`). | No account authentication. |
| Development | mise | CLI | Official installer | Runtime and toolchain version manager. | Bootstrap only; selected toolchains add mise globals and shim PATH to `~/.profile`. |
| Development | Visual Studio Code Insiders | GUI, CLI | Microsoft APT repository | Microsoft’s pre-release editor and its `code-insiders` terminal CLI. | No extensions, settings sync, or login. |
| Development | Beyond Compare 5 | GUI, CLI | Official `.deb` via APT | File and folder comparison tool. | Its vendor update repository is enabled by the package. License registration remains user-directed. |
| Hardware | fwupd | CLI, Service | APT | Firmware update framework. | No firmware update is initiated. |
| Hardware | Kanata | CLI, Service | APT and systemctl | Keyboard remapping engine. | Installs/enables one privileged system service and creates the tracked user keymap symlink; no user service. |
| Monitoring / power | thermald | Service | APT and systemctl | Thermal-management daemon. | Enabled after TLP policy is written; no manual sensor probing is run. |
| Monitoring / power | Timeshift | GUI | APT | System snapshot and restore utility. | No snapshot schedule or target is configured. |
| Monitoring / power | TLP | Service | APT and systemctl | Laptop power-management stack. | Applies `50-dotfiles-workstation.conf`, enables TLP, and masks `power-profiles-daemon`. |
| Package management | APT / Aptitude / Nala | CLI | APT | Native Debian package-management tools. | Removes/pins Snap and runs APT cleanup. |
| Productivity | AppFlowy | GUI | Flatpak | Local-first workspace and notes application. | No workspace or account. |
| Productivity | LocalSend | GUI | Flatpak | Local-network file sharing. | No pairing. |
| Productivity | Obsidian | GUI | Flatpak | Markdown knowledge-base application. | No vault or account. |
| System utilities | ansilove | CLI | APT | Render ANSI art to image formats. | No configuration. |
| System utilities | ddgr | CLI | APT | DuckDuckGo command-line search. | No configuration. |
| System utilities | MPV | GUI, CLI | APT | Lightweight media player. | No configuration. |
| System utilities | wakeonlan | CLI | APT | Send Wake-on-LAN packets. | No configuration. |
| System utilities | yt-dlp | CLI | APT | Media downloader for supported sites. | No configuration. |
| System utilities | youtubedl-gui | GUI | APT | Graphical media-download helper. | No configuration. |
| User applications | Aurora Media Player | GUI | Flatpak | Desktop media player. | No configuration. |
| User applications | GNOME Podcasts | GUI | Flatpak | Podcast client. | No subscriptions. |
| User applications | ncspot | CLI | Flatpak | Terminal Spotify client. | No account login. |
| User applications | RustConn | GUI | Flatpak | Remote-connections desktop client. | No connection profile. |
| User applications | RustDesk | GUI | Flatpak | Remote desktop client. | No device/account configuration. |

## Shell environment

These are mandatory shell tools. Hydration creates compatibility names for
Ubuntu's `batcat` and `fdfind`, then uses `hydrate:shell-config` to run the
existing Git, Fastfetch, and Zsh configuration tasks. The linked Zsh profile
sets `EDITOR` and `VISUAL` to Fresh when it is available.

| Application | Install Method | Hydration configuration |
|---|---|---|
| Bat, Eza, Fastfetch, Fd, Fzf, Ripgrep, Starship, Zoxide | APT, with Linuxbrew fallback for a missing command | Links Fastfetch and Zsh configuration; creates `bat`/`fd` compatibility shims. |
| Zsh | APT | Links `os/linux/config/zsh/dot.zshrc`. |
| Fresh Editor | Official `.deb` via APT | Mandatory editor; the linked Zsh profile makes it `$EDITOR` and `$VISUAL`. |
| Micro and Vim | APT | Baseline terminal editors. |
| Leaf | Official installer | Installed in `~/.local/bin`. |

## Optional apps

These applications are installed only if selected in the Gum questionnaire.
Rank expresses the wording and intent in that menu; it is not a quality score.

| Category | Application | Type | Rank | Short Description | Post-install setup / plugins / customizations |
|---|---|---|---|---|---|
| AI agents | Claude Code | CLI | Omarchy prewired | Anthropic coding-agent CLI. | Installed only; authentication and configuration are user-directed. |
| AI agents | Gemini CLI | CLI | Alternative | Google’s terminal AI agent. | Installed only; authentication and configuration are user-directed. |
| AI agents | GitHub Copilot CLI | CLI | Omarchy prewired | GitHub’s coding assistant for the terminal. | Installed only; authentication and configuration are user-directed. |
| AI agents | OpenAI Codex | CLI | Omarchy prewired | OpenAI coding-agent CLI. | Installed only; authentication and configuration are user-directed. |
| AI agents | OpenCode | CLI | Omarchy prewired | Open-source coding-agent CLI. | Installed only; provider configuration is user-directed. |
| AI / local models | Ollama | CLI, Service | Optional | Local model runner and API service. | Official installer; no model is pulled. |
| Ancillary tools | Lazygit | CLI | Omarchy pre-installed | Terminal UI for Git operations. | No configuration. |
| Connectivity | NetworkManager OpenVPN plugin | GUI | Optional | Integrates OpenVPN connections into GNOME network settings. | APT; no VPN profile or credentials are imported. |
| Browsers | Chromium | GUI | Optional | Flathub Chromium with a Wayland gesture launcher. | Creates a user launcher with Wayland decorations and touchpad history navigation. |
| Browsers | Firefox | GUI | Default | Flathub Firefox, never the Snap build. | Flatpak only; no browser profile customization. |
| Browsers | Google Chrome | GUI | Optional | Official Chrome `.deb` with Wayland, gesture, and GLIC settings. | Creates a user launcher with Wayland decorations, touchpad navigation, and GLIC flags. |
| Development toolchains | Go | CLI | Optional | Current Go installed and globally activated through mise. | `mise use --global`; mise shims are added to `~/.profile`. |
| Development toolchains | Java | CLI | Optional | Current Java installed and globally activated through mise. | `mise use --global`; mise shims are added to `~/.profile`. |
| Development toolchains | Node.js LTS | CLI | Recommended | Node LTS installed and globally activated through mise. | `mise use --global`; mise shims are added to `~/.profile`. |
| Development toolchains | Python | CLI | Optional | Current Python through mise, separate from Ubuntu Python. | `mise use --global`; mise shims are added to `~/.profile`. |
| Development toolchains | Rust | CLI | Optional | Stable Rust installed and globally activated through mise. | `mise use --global`; mise shims are added to `~/.profile`. |
| File managers | Carelo | GUI | Optional | Local-first, dual-pane file manager. | Extracted AppImage gets user wrapper, icon, desktop entry, and cache refresh. |
| File managers | Spacedrive v2 | GUI, Service | Experimental | Multi-device file-library manager. | Extracted package gets user wrapper/desktop integration; library setup is first-run. |
| File managers | Yazi | CLI | Optional | Terminal file manager with Git, smart-enter, jump-to-char, toggle-pane, diff, and smart-paste plugins. | Installs the listed six Yazi plug-ins. |
| GNOME tiling | O-Tiling | GUI | Recommended | GNOME Shell tiling extension. | Installed for the detected Shell version; other managed tilers are disabled; logout/login activates it. |
| GNOME tiling | PaperWM | GUI | Specialized alternative | Scrollable GNOME tiling extension. | Installed for the detected Shell version; other managed tilers are disabled; logout/login activates it. |
| GNOME tiling | Simple Tiling | GUI | Minimal fallback | Lightweight GNOME tiling extension. | Installed for the detected Shell version; other managed tilers are disabled; logout/login activates it. |
| GNOME tiling | Tiling Shell | GUI | Alternative | Feature-rich GNOME tiling extension. | Installed for the detected Shell version; other managed tilers are disabled; logout/login activates it. |
| Hardware | OpenLogi | GUI | Optional | Local-first Logitech Options+ replacement. | Official `.deb`; it does not require Piper or ratbagd. |
| Hardware | Piper and ratbagd | GUI, Service | Optional | Configure supported gaming mice. | APT; Piper is the ratbagd frontend, with no device profile changed. |
| Mail | Thunderbird | GUI | Optional | Mail and calendar client. | Flatpak only; no account. |
| Mail | Betterbird | GUI | Optional | Thunderbird-derived mail and calendar client. | Official Linux archive with a user-local launcher; no account. |
| Multiplexers | Tmux | CLI | Recommended | Established terminal multiplexer. | No configuration. |
| Multiplexers | Zellij | CLI | Alternative | Modern terminal multiplexer. | Official release binary is installed to `~/.local/bin`; no layout/config. |
| Resource monitoring | Mission Center | GUI | Optional | GUI dashboard for processes, GPU, and sensors. | Flatpak only; no configuration. |
| Speech to text | Speech Note | GUI | Alternative | Mature offline dictation application from Flathub. | Flatpak only; model and microphone setup are first-run. |
| Speech to text | Vocalinux | GUI | Low-resource | VOSK-based offline dictation AppImage. | User wrapper/desktop entry with AppImage extraction mode; model/microphone setup is first-run. |
| Speech to text | Voquill | GUI | Alternative | Cross-platform dictation with account and trial flows. | User wrapper/desktop entry with AppImage extraction mode; account/model setup is first-run. |
| Speech to text | Voxtype | GUI | Recommended | Omarchy-associated local dictation application. | User-local extraction/wrapper plus Wayland input/clipboard support; model setup is first-run. |
| Terminal editors | Neovim | CLI | Omarchy default | Extensible modal terminal editor. | No plug-ins or configuration. |
| Terminal emulators | Alacritty | GUI | Optional | Fast GPU-accelerated terminal. | No configuration. |
| Terminal emulators | Foot | GUI | Omarchy default | Lightweight Wayland-native terminal. | No configuration. |
| Terminal emulators | Ghostty | GUI | Optional | GPU-accelerated modern terminal. | No configuration. |
| System utilities | Synergy | GUI, Service | Optional | Share a keyboard and mouse across machines. | APT; no peer or service configuration. |
