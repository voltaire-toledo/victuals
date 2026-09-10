# System Hydration

This directory contains scripts and documentation for restoring ("hydrating") applications, documents, settings, and customizations onto fresh Linux installations.

## Fresh Ubuntu workflow

From the repository root, install Go Task and then open the task menu:

```bash
./install/install-task.sh
task
```

Plain `task` only lists available actions. It never starts hydration. To run the
guided Ubuntu workflow:

```bash
task hydrate
```

Hydration first installs and validates Gum and go-task, then collects terminal,
browser, GNOME tiling-extension, offline speech-to-text, and AI-agent choices
before changing applications or desktop policy. Its terminal default preserves
Ubuntu GNOME's pre-installed Console; Foot is Omarchy
Quattro's bundled default, while Ghostty and Alacritty are optional. It then
removes and pins Snap, installs the common
application SBOM, configures power management, selects Intel-only graphics,
lightens GNOME, and enables Kanata. A reboot is normally required afterward.

Tiling choices are GNOME Shell extensions only, not desktop environments or
replacement window managers. GNOME Extensions, Extension Manager, and GNOME
Tweaks are always installed, including when no tiling extension is selected.

The questionnaire always retains Ubuntu's Files plus Nano and Vim as baseline
file-management and terminal-editing tools. It can additionally install Carelo,
Yazi (with curated base plugins), and experimental Spacedrive v2; terminal-editor
selections cover Fresh or Quattro's Neovim, while Micro is a mandatory shell
baseline; Tmux or Zellij; an expanded
AI-agent set; and a separate optional group of Quattro-preinstalled CLI/TUI tools
(Lazygit, yt-dlp, and Gum; Zoxide and Starship are mandatory shell tools). GNOME System Monitor and btop
are also baseline resource monitors; Mission Center is an optional richer GUI
dashboard. Before optional applications are installed, hydration also prepares
`.deb`/AppImage support, Flatpak with Flathub, Linuxbrew, and mise. The
mise-managed development-toolchain prompt offers Node LTS, Python, Rust, Go,
and Java without replacing Ubuntu's system Python.

For the complete, script-derived package and application inventory, see the
[Ubuntu hydration SBOM](docs/UBUNTU-SBOM.md). The design rationale is in
[HYDRATION-DESIGN.md](docs/HYDRATION-DESIGN.md).

For local NVIDIA model work, switch modes and reboot:

```bash
task hydrate:gpu-compute
```

Return to the maximum-battery configuration with `task hydrate:gpu-integrated`
and another reboot.

## Definition catalogs

The selectable application and policy metadata is maintained in
[`../victuals/definitions/`](../victuals/definitions/). The Ubuntu script reads
and validates those target-neutral definitions before presenting the guided
choices; package-manager commands, ordering, privilege, and validation remain
in the Linux adapters.

## Available Hydration Scripts

### Ubuntu Desktop 26.04
- **Script:** [`hydrate_u2604.sh`](hydrate_u2604.sh)
- **Description:** A comprehensive bash script that installs APT packages, Snaps, Flatpaks, Homebrew formulas, and restores user dotfiles/configurations for a fresh Ubuntu 26.04 installation. 
- **Usage:** 
  ```bash
  chmod +x os/linux/hydrate_u2604.sh
  ./os/linux/hydrate_u2604.sh
  ```

### Omarchy 4 (Quattro)
- **Script:** [`hydrate_omarchy4.sh`](hydrate_omarchy4.sh)
- **Description:** An adaptation of the hydration method specifically designed for Omarchy 4 (an Arch-based distribution). It utilizes `pacman` and `yay` (AUR) instead of APT and Snaps to provision the same application catalog and dotfiles.
- **Usage:** 
  ```bash
  chmod +x os/linux/hydrate_omarchy4.sh
  ./os/linux/hydrate_omarchy4.sh
  ```

## Documentation
- [`APPLICATIONS.md`](APPLICATIONS.md): The full inventory of all packages and configuration locations discovered on the source system, broken down by installation method.
