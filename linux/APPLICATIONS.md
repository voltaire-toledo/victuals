# Ubuntu Desktop 26.04 System Inventory & Hydration Guide

This document catalogs the applications, tools, and custom configurations on this system, categorized by their installation method. 

**Package Management Precedence Policy:**
When adding new tools or reviewing installations, the following hierarchy is preferred (highest to lowest): `apt/deb` > `AppImage` > `linuxbrew` > `flatpak` > `mise` > `pnpm` > `npm` > `pip`. Snap packages are strictly avoided.

Re-installation scripts are provided at the end of each section to recreate the environment on a fresh machine.

## APT Packages

The following packages were manually installed via the system package manager (APT). This excludes base system libraries and dependencies that are automatically installed.

**Notable Applications & Tools:**
- `appflowy`, `appimagelauncher`, `bcompare`, `chatgpt`, `code-insiders`, `google-chrome-stable`, `micro`, `moebius`, `mpv`, `synergy`, `youtubedl-gui`
- **Development & CLI Tools:** `aptitude`, `btop`, `bubblewrap`, `build-essential`, `curl`, `ddgr`, `fzf`, `gh`, `ghostty`, `git`, `htop`, `nala`, `neovim`, `podman`, `podman-compose`, `python3`, `rez2ans-next`, `tailscale`, `tmux`, `zsh`
- **System Utilities:** `cockpit`, `gnome-tweaks`, `piper`, `ratbagd`, `timeshift`

### Reinstall APT Packages
```bash
#!/bin/bash
# Update and install APT packages
sudo apt-get update
sudo apt-get install -y \
  appflowy appimagelauncher aptitude bcompare btop bubblewrap build-essential \
  chatgpt cockpit code-insiders curl ddgr fzf gh ghostty git gnome-tweaks \
  google-chrome-stable htop micro moebius mpv nala neovim piper podman \
  podman-compose python3 ratbagd rez2ans-next synergy tailscale timeshift \
  tmux youtubedl-gui zsh
```

## Snap Packages

Snaps are containerized software packages provided by Canonical.

**Installed Snaps:**
- `bare`, `core24` (Base Snaps)
- `desktop-security-center`, `firmware-updater`, `prompting-client`, `snap-store`, `snapd`, `snapd-desktop-integration` (System/Canonical Tools)
- `gnome-46-2404`, `gtk-common-themes`, `mesa-2404` (Desktop/Graphics Dependencies)

### Reinstall Snap Packages
```bash
#!/bin/bash
# Install Snap packages
sudo snap install desktop-security-center
sudo snap install firmware-updater
sudo snap install prompting-client
```
*(Note: Most core Snaps are pre-installed on Ubuntu 26.04 or installed automatically as dependencies).*

## Flatpak Packages

Flatpak applications installed on the system, primarily used for GUI applications and sandboxing.

**Installed Flatpaks:**
- Extension Manager (`com.mattjakeman.ExtensionManager`)
- RustDesk (`com.rustdesk.RustDesk`)
- Aurora Media Player (`io.github.daniacosta_dev.AuroraMediaPlayer`)
- ncspot (`io.github.hrkfdn.ncspot`)
- RustConn (`io.github.totoshko88.RustConn`)
- Podman Desktop (`io.podman_desktop.PodmanDesktop`)
- Obsidian (`md.obsidian.Obsidian`)
- Cockpit Client (`org.cockpit_project.CockpitClient`)
- Podcasts (`org.gnome.Podcasts`)
- LocalSend (`org.localsend.localsend_app`)
- Firefox (`org.mozilla.firefox`)
- Thunderbird ESR (`org.mozilla.thunderbird_esr`)

### Reinstall Flatpak Packages
```bash
#!/bin/bash
# Ensure flatpak is installed and flathub is added
sudo apt install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Flatpak applications
flatpak install -y flathub com.mattjakeman.ExtensionManager
flatpak install -y flathub com.rustdesk.RustDesk
flatpak install -y flathub io.github.daniacosta_dev.AuroraMediaPlayer
flatpak install -y flathub io.github.hrkfdn.ncspot
flatpak install -y flathub io.github.totoshko88.RustConn
flatpak install -y flathub io.podman_desktop.PodmanDesktop
flatpak install -y flathub md.obsidian.Obsidian
flatpak install -y flathub org.cockpit_project.CockpitClient
flatpak install -y flathub org.gnome.Podcasts
flatpak install -y flathub org.localsend.localsend_app
flatpak install -y flathub org.mozilla.firefox
flatpak install -y flathub org.mozilla.thunderbird_esr
```

## LinuxBrew (Homebrew) Packages

Homebrew packages installed for the local user.

**Installed Formulas:**
- `ansilove`, `azure-cli`, `durdraw`, `go-task`, `lazygit`, `wakeonlan`, `zoxide`, `python@3.13`, `python@3.14`

### Reinstall LinuxBrew Packages
```bash
#!/bin/bash
# Install Homebrew if not installed
if ! command -v brew &> /dev/null; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Install Brew formulas
brew install ansilove azure-cli durdraw go-task lazygit wakeonlan zoxide python@3.13 python@3.14
```

## AppImages

Portable standalone applications found in user directories.

**Discovered AppImages:**
- `orca-linux` (~/Applications/orca-linux_706a73edc8ca5e4d9d7126f87989faed.AppImage)
- `Vicinae` (~/Applications/Vicinae-x86_64_cb5b99542479b1f51f73db4a03a92159.AppImage)
- `AppFlowy` (~/Downloads/AppFlowy-0.12.5-linux-x86_64.AppImage)

### Restore AppImages
```bash
#!/bin/bash
# Create Applications directory
mkdir -p ~/Applications

# Note: AppImages need to be downloaded from their respective sources as they are distributed as direct binary downloads.
# Example for AppFlowy:
# wget -O ~/Applications/AppFlowy.AppImage "https://github.com/AppFlowy-IO/AppFlowy/releases/download/0.12.5/AppFlowy-0.12.5-linux-x86_64.AppImage"
# chmod +x ~/Applications/*.AppImage
```

## Custom Configurations (GNOME & System Settings)

User configurations stored in dconf/gsettings and user dotfiles.

### Restore Configurations
```bash
#!/bin/bash
# Restore GNOME settings (Assuming settings were previously dumped using 'dconf dump / > dconf-settings.ini')
# dconf load / < dconf-settings.ini

# Ensure common configuration directories exist
mkdir -p ~/.config
mkdir -p ~/.local/share/applications
```
