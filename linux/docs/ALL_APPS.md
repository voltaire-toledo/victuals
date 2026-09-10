# Installed Applications and Packages

This document catalogs the non-default applications, packages, and custom binaries installed on the system, organized by installation method.

## APT Packages (Manually Installed)

| Package | Description / Category |
|---------|------------------------|
| `appflowy` | Note-taking workspace |
| `appimagelauncher` | AppImage integration |
| `btop` | Resource monitor |
| `cockpit` | Server admin interface |
| `curl` | Command line URL transfer |
| `fastfetch` | System info tool |
| `fresh-editor` | Text editor |
| `fzf` | Command-line fuzzy finder |
| `gh` | GitHub CLI |
| `ghostty` | Terminal emulator |
| `google-chrome-stable` | Web browser |
| `htop` | Process viewer |
| `input-remapper` | Input device configuration |
| `jq` | Command-line JSON processor |
| `micro` | Terminal-based text editor |
| `moebius` | Terminal client/tool |
| `mpv` | Media player |
| `nala` | APT frontend |
| `neovim` | Text editor |
| `piper` | Mouse configuration tool |
| `podman` | Container engine |
| `podman-compose` | Compose for podman |
| `ratbagd` | Mouse configuration daemon |
| `rez2ans-next` | Image to ANSI tool |
| `tailscale` | VPN/Mesh network |
| `timeshift` | System restore tool |
| `tmux` | Terminal multiplexer |
| `wget` | Command line file retrieval |
| `youtubedl-gui` | Video downloader GUI |
| `zsh` | Z shell |

*(Note: Essential build tools and libraries like `build-essential`, `python3`, `git`, and hardware-specific drivers are also installed manually.)*

## Flatpak Packages

| Application | App ID |
|-------------|--------|
| Aurora Media Player | `io.github.daniacosta_dev.AuroraMediaPlayer` |
| Cockpit Client | `org.cockpit_project.CockpitClient` |
| Extension Manager | `com.mattjakeman.ExtensionManager` |
| Firefox | `org.mozilla.firefox` |
| LocalSend | `org.localsend.localsend_app` |
| ncspot | `io.github.hrkfdn.ncspot` |
| Obsidian | `md.obsidian.Obsidian` |
| Podcasts | `org.gnome.Podcasts` |
| RustDesk | `com.rustdesk.RustDesk` |
| Thunderbird ESR | `org.mozilla.thunderbird_esr` |

## Snap Packages

| Package | Version / Notes |
|---------|-----------------|
| `desktop-security-center` | Ubuntu Security Center |
| `firmware-updater` | Firmware updater tool |
| `prompting-client` | Authentication prompting client |

*(Note: Other installed snaps are standard Ubuntu core and base dependencies.)*

## Custom Binaries & Standalone Applications

### `/usr/local/bin` & `/opt`

| Binary / App | Location | Description |
|--------------|----------|-------------|
| `kanata` | `/usr/local/bin/kanata` | Advanced keyboard remapper |
| `ollama` | `/usr/local/bin/ollama` | Local LLM runner |
| `starship` | `/usr/local/bin/starship` | Cross-shell prompt |
| `Moebius` | `/opt/Moebius` | Standalone application |

### User Binaries (`~/.local/bin`)

| Binary | Location | Description |
|--------|----------|-------------|
| `agy` | `~/.local/bin/agy` | Antigravity CLI |
| `claude` | `~/.local/bin/claude` | Claude CLI / Agent |
| `codex` | `~/.local/bin/codex` | Codex CLI |
| `fresh` | `~/.local/bin/fresh` | Fresh Editor |
| `herdr` | `~/.local/bin/herdr` | Local tool |
| `leaf` | `~/.local/bin/leaf` | Local tool |
| `mise` | `~/.local/bin/mise` | Dev tools manager |
| `ollama` | `~/.local/bin/ollama` | Local LLM runner |
| `orca-ide` | `~/.local/bin/orca-ide` | Orca IDE |
| `touchpad-lock-on-type` | `~/.local/bin/touchpad-lock-on-type` | Custom script |
| `touchpad-wake` | `~/.local/bin/touchpad-wake` | Custom script |
