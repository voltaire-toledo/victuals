#!/bin/bash
# hydrate_omarchy4.sh
# System Hydration Script for Omarchy 4 (Quattro) / Arch Linux
# Restores applications, documents, settings, and customizations from dotfiles.

set -e

REPO_DIR="/home/me/CODE/dotfiles"
USER_HOME=$HOME

echo "===================================================================="
echo " Starting Hydration for Omarchy 4 (Arch Linux)..."
echo " Repository Directory: $REPO_DIR"
echo " User Home Directory: $USER_HOME"
echo "===================================================================="

# 1. Update system and Pacman packages
echo "[1/6] Installing Pacman packages..."
# Note: Snap is strictly avoided on Omarchy. All applications use native/AUR or Flatpak.
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm \
  appflowy base-devel btop bubblewrap curl fzf github-cli git htop \
  jq micro mpv neovim piper podman podman-compose python ratbagd \
  synergy tailscale timeshift tmux wget zsh docker docker-compose \
  fastfetch go-task lazygit wakeonlan zoxide azure-cli

# Install yay if not present
if ! command -v yay &> /dev/null; then
  echo "Installing yay (AUR helper)..."
  sudo pacman -S --needed --noconfirm git base-devel
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  cd /tmp/yay && makepkg -si --noconfirm
  cd -
fi

# 2. AUR Packages (Replacing APT/Brew/Snap packages)
echo "[2/6] Installing AUR packages via yay..."
yay -S --noconfirm \
  visual-studio-code-insiders \
  google-chrome \
  youtubedl-gui \
  ghostty \
  bcompare \
  ansilove \
  durdraw

# 3. Flatpak Packages
echo "[3/6] Installing Flatpak packages..."
sudo pacman -S --noconfirm flatpak
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

# 4. AppImages
echo "[4/6] Restoring AppImages..."
mkdir -p "$USER_HOME/Applications"
mkdir -p "$USER_HOME/Downloads"
echo "  Note: Ensure AppImages (AppFlowy, orca-linux, Vicinae) are downloaded to $USER_HOME/Applications and made executable."

# 5. Custom Binaries
echo "[5/6] Setting up directories for Custom Binaries..."
mkdir -p "$USER_HOME/.local/bin"
sudo mkdir -p /usr/local/bin /opt
echo "  Note: Custom binaries like kanata, ollama, starship, Moebius, agy, claude, codex, fresh, etc. should be placed in their respective paths."

# 6. Configurations (Omarchy / Hyprland / Dotfiles)
echo "[6/6] Restoring Configurations..."
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

echo "  Note: Omarchy 4 uses Lua configurations for Hyprland/Quickshell. Ensure any dotfiles modifications specific to Omarchy 4 are applied manually if they differ."

echo "===================================================================="
echo " Hydration complete!"
echo "===================================================================="
