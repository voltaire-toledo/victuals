#!/bin/bash
# hydrate_u2604.sh
# System Hydration Script for Ubuntu Desktop 26.04
# Restores applications, documents, settings, and customizations from dotfiles.

set -e

REPO_DIR="/home/me/CODE/dotfiles"
USER_HOME=$HOME

echo "===================================================================="
echo " Starting Hydration for Ubuntu Desktop 26.04..."
echo " Repository Directory: $REPO_DIR"
echo " User Home Directory: $USER_HOME"
echo "===================================================================="

# Package Management Preference Order:
# 1. apt/deb
# 2. appimage
# 3. linuxbrew
# 4. flatpak
# 5. mise
# 6. pnpm
# 7. npm
# 8. pip
# Note: Snap is strictly avoided based on preferences.

# 1. Update system and APT packages
echo "[1/6] Installing APT packages..."
sudo apt-get update
sudo apt-get install -y \
  aptitude btop bubblewrap build-essential \
  cockpit curl ddgr fzf gh git gnome-tweaks \
  htop input-remapper jq micro mpv nala neovim piper podman \
  podman-compose python3 ratbagd timeshift \
  tmux wget youtubedl-gui zsh
echo "[3/7] Installing Flatpak packages..."
sudo apt-get install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true

sudo flatpak install -y flathub com.mattjakeman.ExtensionManager \
  com.rustdesk.RustDesk \
  io.github.daniacosta_dev.AuroraMediaPlayer \
  io.github.hrkfdn.ncspot \
  io.github.totoshko88.RustConn \
  io.podman_desktop.PodmanDesktop \
  md.obsidian.Obsidian \
  org.cockpit_project.CockpitClient \
  org.gnome.Podcasts \
  org.localsend.localsend_app \
  org.mozilla.firefox \
  org.mozilla.thunderbird_esr || true

# 4. LinuxBrew (Homebrew) Packages
echo "[4/7] Installing Homebrew packages..."
if ! command -v brew &> /dev/null; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
brew install ansilove azure-cli durdraw go-task lazygit wakeonlan zoxide python@3.13 python@3.14

# 5. AppImages
echo "[5/7] Restoring AppImages..."
mkdir -p "$USER_HOME/Applications"
mkdir -p "$USER_HOME/Downloads"
# Placeholder for manual/scripted AppImage downloads as noted in docs
echo "  Note: Ensure AppImages (AppFlowy, orca-linux, Vicinae) are downloaded to $USER_HOME/Applications and made executable."

# 6. Custom Binaries
echo "[6/7] Setting up directories for Custom Binaries..."
mkdir -p "$USER_HOME/.local/bin"
sudo mkdir -p /usr/local/bin /opt
echo "  Note: Custom binaries like kanata, ollama, starship, Moebius, agy, claude, codex, fresh, etc. should be placed in their respective paths."

# 7. Configurations (GNOME, System Settings, Dotfiles)
echo "[7/7] Restoring Configurations..."
mkdir -p "$USER_HOME/.config"
mkdir -p "$USER_HOME/.local/share/applications"

# Copy configurations from repository
if [ -d "$REPO_DIR/os/linux/config" ]; then
    echo "Copying config files from $REPO_DIR/os/linux/config to $USER_HOME/.config/..."
    cp -r "$REPO_DIR/os/linux/config/"* "$USER_HOME/.config/"
fi

# Copy top-level configuration directories/files
if [ -d "$REPO_DIR/zsh" ]; then
    echo "Copying zsh settings..."
    cp -r "$REPO_DIR/zsh" "$USER_HOME/.zsh"
fi

if [ -f "$REPO_DIR/.editorconfig" ]; then
    cp "$REPO_DIR/.editorconfig" "$USER_HOME/"
fi

# Note about GNOME settings
echo "  Note: GNOME dconf settings should be loaded via 'dconf load / < dconf-settings.ini' if a backup exists."

echo "===================================================================="
echo " Hydration complete!"
echo "===================================================================="
