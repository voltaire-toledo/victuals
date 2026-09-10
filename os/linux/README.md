# System Hydration

This directory contains scripts and documentation for restoring ("hydrating") applications, documents, settings, and customizations onto fresh Linux installations.

## Fresh Ubuntu workflow

From the repository root, bootstrap the minimal Victuals requirements:

```bash
bash os/linux/scripts/hydrate.sh
```

The pre-hydration script installs only missing requirements: `curl`,
`ca-certificates`, and `gum`. Bash, an interactive terminal, `sudo`, `apt`,
and standard shell utilities are assumed to be present on a usable Ubuntu
installation. It reports the bootstrap duration, then hands off directly to
the guided Victuals overview and confirmation prompt.

The remaining hydration workflow will later be invoked after the preset and
installation-plan interface is finalized. For the current Task-based workflow,
from the repository root install Go Task and then open the task menu:

```bash
./install/install-task.sh
task
```

Plain `task` only lists available actions. It never starts hydration. To run the
guided Ubuntu workflow:

```bash
task hydrate
```

To exercise the complete Gum questionnaire, power/GPU and Snap confirmations,
GNOME performance and extension plan, and final ordered installation plan
without changing the system, run:

```bash
task hydrate:preview
```

The direct equivalent is:

```bash
bash os/linux/scripts/ubu.sh preview
```

The selection can be saved as a data-only profile and reused later:

```bash
bash os/linux/scripts/ubu.sh --export workstation.hydration
bash os/linux/scripts/ubu.sh --import workstation.hydration --dry-run
bash os/linux/scripts/ubu.sh --import workstation.hydration
```

The GNOME policy can also be reviewed independently. It presents every
currently supported optimization as a multi-select option with its pros and
cons, then applies only the confirmed choices:

```bash
task hydrate:gnome-optimize
bash os/linux/scripts/gnome-optimize.sh --dry-run
```

Use `--all` to select the complete current policy without prompting. The
standalone policy changes only the current user's GNOME settings and extensions;
it does not use `sudo`.

`--import` skips the category menus but retains the overview, power/GPU, Snap,
and final approval prompts. `--dry-run` and `--plan-mode` stop before every
system-changing operation; `--export` only writes the explicitly requested
profile file. Profiles use versioned tab-separated data rather than executable
shell code.

In the Gum menus, use the arrow keys to move, Space to toggle a multi-select
item, and Enter to confirm. In category menus, select `← Back` and press
Space followed by Enter, or press Esc, to return to the previous category.
Press Ctrl+C at any point to cancel the run cleanly; the script stops before
starting another phase and prints a cancellation message.

This preview does not request `sudo`, create a hydration report, invoke package
managers, download files, modify GNOME settings or extensions, change power or
GPU policy, manage services, or delegate installation to Task. It assumes Gum
is already installed so it can render the real prompts.

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

## Battery Drain Diagnostics

The `battdrain` command provides three complementary views of battery usage:

1. **Current status** — `battdrain` shows the battery percentage, charge state,
   current drain rate, and estimated time remaining using `upower`.
2. **Average drain** — `battdrain avg` samples power consumption and reports
   average wattage using `powerstat`.
3. **Drain causes** — `battdrain diag` opens `powertop` to identify processes,
   devices, and wakeups that may be consuming power.

Install the required Ubuntu packages with:

```bash
sudo apt install upower powerstat powertop
```

The command is installed into `~/.local/bin` by the repository task:

```bash
task battdrain:config
battdrain --help
```

## Available Hydration Scripts

### Ubuntu Desktop 26.04
- **Script:** [`hydrate_u2604.sh`](hydrate_u2604.sh)
- **Description:** A comprehensive bash script that installs APT packages, Snaps, Flatpaks, Homebrew formulas, and restores user dotfiles/configurations for a fresh Ubuntu 26.04 installation. 
- **Usage:** 
  ```bash
  chmod +x os/linux/hydrate_u2604.sh
  ./os/linux/hydrate_u2604.sh
  ```

## Documentation
- [`APPLICATIONS.md`](APPLICATIONS.md): The full inventory of all packages and configuration locations discovered on the source system, broken down by installation method.
