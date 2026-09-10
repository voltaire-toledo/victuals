# macOS Applications & Custom Configurations

## App Store

Mac App Store applications installed on this system.

- CleanMyKeyboard
- Prime Video
- Sofa
- Windows App
- uBlock Origin Lite

```bash
# Requires `mas` to be installed (which can be installed via Homebrew)
# Note: You must be signed into the Mac App Store first.
# Dependencies: Homebrew, mas

# Example installation using `mas` (IDs can be found via `mas search <name>`)
mas install 1114515510 # CleanMyKeyboard (example ID)
mas install 545804561  # Prime Video
mas install 1507310329 # Sofa
mas install 1295203466 # Windows App
mas install 1463298887 # uBlock Origin Lite
```

## Download & Install

These applications were installed manually via `.dmg`, `.pkg`, or direct downloads rather than through Homebrew or the App Store.

- Antigravity IDE
- Antigravity
- AppCleaner
- Beyond Compare
- Bitwarden (Desktop App)
- Blip
- BrewBrowser
- ChatGPT
- Claude
- Comet
- Droppy
- Flameshot
- Glaze
- Google Chrome
- Google Docs / Sheets / Slides (Chrome PWAs)
- LM Studio
- Microsoft Defender Shim
- Microsoft Edge
- Microsoft Office (Excel, OneNote, Outlook, PowerPoint, Teams, Word)
- Notion
- Ollama
- OneDrive
- OrbStack
- Python 3.14
- Raycast
- Recordly
- RustDesk
- Slack
- Snipaste
- Synergy
- Tailscale
- VMware Fusion
- Visual Studio Code - Insiders
- Warp
- WhatCable
- Logitech G HUB (lghub)
- Logi Options+ (logioptionsplus)

```bash
# Many of these are available via Homebrew Casks, which is the recommended way to automate.
# For strictly manual installs, user intervention is required:
echo "Please download and install the following manually from their respective websites:"
echo "- Antigravity / Antigravity IDE"
echo "- Blip, BrewBrowser, Comet, Droppy, Recordly, WhatCable"
echo "- Microsoft Office Suite (if not switching to Homebrew Cask)"
echo "- VMware Fusion"
echo "- Logi Options+ and G HUB"
# If scripted via dmg/pkg:
# curl -O https://example.com/app.dmg
# hdiutil attach app.dmg
# cp -R /Volumes/App/App.app /Applications/
# hdiutil detach /Volumes/App
```

## AppImage

- *None*

```bash
# No applications to install in this category.
# AppImages are natively a Linux packaging format and not used on macOS.
```

## Homebrew

### Taps
- `0xmassi/stik`
- `anomalyco/tap`
- `go-task/tap`
- `jandedobbeleer/oh-my-posh`
- `marcus/tap`
- `neurosnap/tap`
- `teamookla/speedtest`
- `xykong/tap`

### Formulae (CLI tools)
- `ansible`, `azure-cli`, `bash`, `bat`, `bitwarden-cli`, `cask`, `chafa`, `ddgr`, `eza`, `fastfetch`, `ffmpeg`, `fnm`, `fresh-editor`, `fzf`, `gh`, `git`, `git-filter-repo`, `go-task`, `imagemagick`, `imagemagick-full`, `kanata`, `kanata-tray`, `lazygit`, `ncspot`, `powershell`, `python@3.12`, `rclone`, `restic`, `ripgrep`, `rtk`, `terraform-docs`, `yazi`, `yt-dlp`, `zellij`, `zoxide`, `anomalyco/tap/opencode`, `neurosnap/tap/zmx`

### Casks (GUI applications)
- `applite`, `bettershot`, `caffeine`, `cmux`, `copilot-cli`, `fluidvoice`, `flux-markdown`, `font-jetbrains-mono-nerd-font`, `ghostty`, `github`, `go-task/tap/go-task`, `iterm2`, `keycastr`, `localsend`, `notunes`, `obsidian`, `oh-my-posh`, `openlogi`, `pearcleaner`, `shortcat`, `signal`, `spacedrive`, `stik`, `supacode`, `thaw@beta`

```bash
# Install Homebrew first
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Taps must be added before formulas and casks that rely on them
brew tap 0xmassi/stik
brew tap anomalyco/tap
brew tap go-task/tap
brew tap jandedobbeleer/oh-my-posh
brew tap marcus/tap
brew tap neurosnap/tap
brew tap teamookla/speedtest
brew tap xykong/tap

# Install Formulae (Dependencies for other CLI tools and scripts)
brew install ansible azure-cli bash bat bitwarden-cli cask chafa ddgr eza fastfetch ffmpeg fnm fresh-editor fzf gh git git-filter-repo go-task imagemagick imagemagick-full kanata kanata-tray lazygit ncspot powershell python@3.12 rclone restic ripgrep rtk terraform-docs yazi yt-dlp zellij zoxide anomalyco/tap/opencode neurosnap/tap/zmx

# Install Casks (GUI Applications)
brew install --cask applite bettershot caffeine cmux copilot-cli fluidvoice flux-markdown font-jetbrains-mono-nerd-font ghostty github go-task/tap/go-task iterm2 keycastr localsend notunes obsidian oh-my-posh openlogi pearcleaner shortcat signal spacedrive stik supacode thaw@beta
```

## Other

- **VSCode Extensions**: (e.g., Python, Docker, GitHub Actions, Terraform)
- **Cargo Packages**: (e.g., `zellij`)
- **UV/Python Packages**: (e.g., `graphifyy`)
- **NPM Packages**: (e.g., `@google/gemini-cli`, `@openai/codex`, `@rivolink/leaf`, `list`)
- **Chrome / Edge Apps**: (e.g., Claude Code URL Handler)

```bash
# Node Packages (Requires fnm/Node.js to be installed first)
npm install -g @google/gemini-cli @openai/codex @rivolink/leaf list

# Cargo Packages (Requires Rust/Cargo to be installed first)
cargo install zellij

# UV Packages (Requires uv to be installed first)
uv tool install graphifyy --source "git+https://github.com/safishamsi/graphify"

# VSCode Extensions (Requires Visual Studio Code to be installed first)
code-insiders --install-extension ms-python.python
code-insiders --install-extension ms-python.debugpy
code-insiders --install-extension ms-azuretools.vscode-docker
# ... continue for other extensions
```

---

# System Deployment Strategy: Adversarial Agentic Debate

**Objective:** Determine the most viable way to deploy all applications and configurations on a freshly reset MacBook Air with only a single `sudo` capable user, assuming no pre-installed additional software.

## The Debate

**Agent A (The Configuration Management Advocate - Ansible):** 
"The optimal approach is to use Ansible. We should write an idempotent playbook. Ansible has excellent modules for `homebrew`, `homebrew_cask`, `osx_defaults`, and managing symlinks. It abstracts away the OS-level differences, provides robust error handling, and ensures the machine strictly matches the desired state. If a script fails halfway, it breaks; if Ansible fails, you just re-run it."

**Agent B (The macOS Native Pragmatist - Bash + Brewfile):**
"Ansible is complete overkill for a single-user macOS environment and introduces a chicken-and-egg problem. On a fresh macOS, Python and Ansible aren't installed. We'd have to write a Bash script just to install Homebrew, Python, and Ansible before we can even run the playbook. 
Instead, we should use a `Brewfile` managed by `brew bundle`. Homebrew is already the de facto package manager on macOS. A single `Brewfile` can install Taps, Formulae, Casks, Mac App Store apps (via `mas`), and even VSCode extensions natively. A simple Bash bootstrap script to install Homebrew, clone the dotfiles repo, run `brew bundle`, and use GNU `stow` for dotfile symlinks is far lighter, faster, and requires zero complex tooling overhead."

**Agent C (The Declarative Purist - Nix-Darwin):**
"Both Ansible and Bash scripts mutate system state and are prone to drift. We should use `nix-darwin` and `home-manager` to declare the entire system state functionally. This guarantees exact reproducibility."

**Agent B (Rebuttal):**
"The user requested the *most viable* way. Nix has a massive learning curve, often struggles with macOS native GUI applications (which the user has dozens of), and makes simple tasks like installing a new App Store app unnecessarily complex. The `Brewfile` is a text file that can be auto-generated (`brew bundle dump`) and version controlled easily."

**Agent A (Concession):**
"Given the constraint of a freshly reset machine and the sheer volume of macOS GUI applications and App Store apps, the `Brewfile` handles the macOS ecosystem more natively than Ansible's Python modules. I concede that for a single user bootstrapping macOS, a Brewfile and a minimal shell script is the most frictionless path."

## Conclusion: The Most Viable Deployment Method

The definitive best practice for this scenario is a **Bash Bootstrap Script + Brewfile + GNU Stow**.

### The Deployment Sequence:
1. **Initial Bootstrap:** 
   Open Terminal and execute a one-liner to download the bootstrap script:
   `bash -c "$(curl -fsSL https://raw.githubusercontent.com/username/dotfiles/main/bootstrap.sh)"`
2. **Xcode Command Line Tools:** 
   The script first runs `xcode-select --install` to provide `git` and compiling tools.
3. **Install Homebrew:** 
   The script runs the official Homebrew install curl command.
4. **Clone Repository:** 
   `git clone` the dotfiles repository to `~/.dotfiles`.
5. **Install All Packages (The Heavy Lifting):** 
   Run `brew bundle --file=~/.dotfiles/Brewfile`. This single command idempotently installs:
   - All Taps and CLI tools.
   - All GUI applications (Casks).
   - All App Store apps (via `mas` integration in the Brewfile).
   - All VSCode extensions.
6. **Symlink Configurations:** 
   Use `stow` (installed via the Brewfile) to symmetrically link custom configurations (like `~/.zshrc`, `~/.config/ghostty`, etc.) from the dotfiles repo into the home directory.
7. **macOS Defaults:** 
   Execute a `macos_defaults.sh` script to set system preferences (dock size, key repeat rates, finder settings) using `defaults write`.
8. **Language Ecosystems (Post-Install):** 
   Run `npm install -g`, `cargo install`, and `uv tool install` for the remaining non-brew packages. 

This approach minimizes dependencies, uses tools native to the macOS ecosystem, and provides a completely automated setup from a fresh OS.
