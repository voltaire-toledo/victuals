# Zsh Configuration

A modern, feature-rich zsh setup with oh-my-zsh, Powerlevel10k theme, and powerful CLI tools integration.

## Requirements

### Core Shell Framework
- **oh-my-zsh** — Plugin manager and configuration framework for zsh
- **Powerlevel10k** — High-performance, responsive theme with instant prompt support

### Plugins
- `git` — Git completions and aliases
- `azure` — Azure CLI completions
- `terraform` — Terraform completions
- `docker` — Docker completions
- `zsh-autosuggestions` — Fish-like autosuggestions as you type
- `zsh-syntax-highlighting` — Syntax highlighting for commands

### CLI Tools (Replacements & Enhancements)
- **eza** — Modern `ls` replacement with icons and tree output
- **bat** — Syntax-highlighted `cat` replacement
- **ripgrep (rg)** — Fast regex-based `grep` replacement
- **fzf** — Fuzzy finder for interactive command-line filtering

### Required Software
- **Homebrew** — macOS package manager
- **Python 3.14** — Latest Python version
- **Bitwarden CLI (bw)** — Secrets manager client
- **fastfetch** — System information display

### Optional Integration
- **OrbStack** — Docker Desktop alternative
- **nlsh** — Custom local shell utilities
- **Bitwarden Secrets Manager** — Access token for credential management

## Installation

### Automated Setup (Recommended)

Run the install script to set up everything automatically:

```bash
cd /path/to/zsh
chmod +x install-zsh-setup.sh
./install-zsh-setup.sh
```

The script will:
1. Install Homebrew (if not present)
2. Install all required tools and CLI utilities
3. Install oh-my-zsh and Powerlevel10k
4. Install zsh plugins
5. Backup existing `.zshrc` and `.zprofile`
6. Link configuration files to your home directory
7. Set zsh as default shell

### Manual Setup

If you prefer manual installation, see [Manual Installation Steps](#manual-installation-steps) below.

## Configuration Files

### `.zprofile`
Loaded on login shells. Sets up:
- Homebrew environment
- Python 3.14 PATH
- OrbStack integration
- nlsh PATH configuration

**Source this file from your home directory:**
```bash
ln -s /path/to/zsh/.zprofile ~/.zprofile
```

### `.zshrc`
Loaded on interactive shells. Includes:
- oh-my-zsh framework initialization
- Powerlevel10k theme and instant prompt
- Plugin configuration
- Custom aliases
- Environment variables
- fzf integration
- Bitwarden CLI completions
- System information display (fastfetch)

**Source this file from your home directory:**
```bash
ln -s /path/to/zsh/.zshrc ~/.zshrc
```

## Features & Usage

### Modern Command Aliases
```bash
ls          # eza with icons and directory grouping
cat FILE    # bat with syntax highlighting and line numbers
grep TERM   # ripgrep (rg) for fast searching
c [DIR]     # Open in Visual Studio Code
ci [DIR]    # Open in Visual Studio Code Insiders
```

### Interactive Features
- **Autosuggestions** — Start typing and zsh suggests previous commands (press → to accept)
- **Syntax Highlighting** — Real-time command validation before execution
- **Fuzzy Finder (fzf)** — Press `Ctrl+R` to search history, `Ctrl+T` to browse files
- **Tab Completion** — Git branches, Azure resources, Docker containers, Terraform resources

### Plugin-Specific Features

#### Git Plugin
- Branch aliases and shortcuts
- Status commands
- Interactive log browsing

#### Azure Plugin
- Azure CLI completions
- Resource group and subscription shortcuts

#### Docker Plugin
- Container and image completions
- Common docker-compose shortcuts

#### Terraform Plugin
- Terraform subcommand completions
- Plan/apply helpers

### Environment & Secrets

#### Bitwarden Secrets Manager
The `.zshrc` includes access to Bitwarden Secrets Manager via the `BWS_ACCESS_TOKEN` environment variable. This enables secure secrets retrieval:

```bash
bw completion --shell zsh  # Bitwarden CLI completions
```

**Note:** The access token is exported in `.zshrc`. Rotate this token regularly for security.

#### Custom PATH Extensions
- `~/.local/bin` — Custom local scripts and utilities
- Python 3.14 framework (if installed)
- OrbStack command-line tools
- antigravity tools

## Powerlevel10k Customization

To configure Powerlevel10k interactively:

```bash
p10k configure
```

This opens a configuration wizard to customize:
- Prompt style (lean, pure, etc.)
- Colors and icons
- Directory truncation
- Time display
- Git status rendering

The configuration is saved to `~/.p10k.zsh`.

## Manual Installation Steps

If the install script doesn't work for your setup:

### 1. Install Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install CLI Tools
```bash
brew install eza bat ripgrep fzf bitwarden-cli fastfetch python@3.14
```

### 3. Install oh-my-zsh
```bash
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### 4. Install Powerlevel10k
```bash
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
```

### 5. Install zsh Plugins
```bash
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

### 6. Link Configuration Files
```bash
ln -s /path/to/zsh/.zshrc ~/.zshrc
ln -s /path/to/zsh/.zprofile ~/.zprofile
```

### 7. Set Zsh as Default Shell
```bash
chsh -s $(which zsh)
```

## Verification

After installation, verify your setup:

```bash
# Check zsh version
zsh --version

# Verify oh-my-zsh installation
echo $ZSH

# Check plugin activation
echo $plugins

# Test CLI replacements
ls --version  # Should show eza
cat --version  # Should show bat
grep --version  # Should show ripgrep

# Test fzf
fzf --version

# Test completions
bw completion --shell zsh
```

## Troubleshooting

### Plugins Not Loading
- Verify `$ZSH` points to `~/.oh-my-zsh`
- Check plugin names in `plugins=()` array
- Ensure plugin directories exist under `~/.oh-my-zsh/custom/plugins`
- Run `omz reload` to reload configuration

### Powerlevel10k Not Displaying
- Ensure Powerlevel10k is cloned to `~/.oh-my-zsh/custom/themes/powerlevel10k`
- Install a Nerd Font: `brew install font-meslo-lg-nerd-font`
- Update terminal font settings to use the Nerd Font
- Run `p10k configure` to reconfigure

### CLI Tool Aliases Not Working
- Verify tools are installed: `brew list eza bat ripgrep fzf`
- Check alias definitions in `.zshrc`
- Ensure `.zshrc` is sourced in your shell session

### OrbStack Integration Failing
- Verify OrbStack is installed and running
- Check `~/.orbstack/shell/init.zsh` exists
- Uncomment the OrbStack line in `.zprofile` if needed

### Bitwarden Completions Not Working
- Verify `bw` is installed: `which bw`
- Check the `BWS_ACCESS_TOKEN` environment variable is set
- Regenerate completions: `bw completion --shell zsh`

## First-Time Setup Checklist

After installation:
- [ ] Install a Nerd Font for proper icon display
- [ ] Run `p10k configure` to customize theme
- [ ] Test `Ctrl+R` (history search) and `Ctrl+T` (file browse)
- [ ] Verify git plugin: `git status` with colored output
- [ ] Test Azure plugin: `az account list`
- [ ] Set up Bitwarden: `bw unlock` with your master password
- [ ] Update `BWS_ACCESS_TOKEN` if using Secrets Manager
- [ ] Review and customize aliases in `.zshrc` as needed

## Updates & Maintenance

### Update oh-my-zsh
```bash
omz update
```

### Update Plugins (if installed manually)
```bash
git -C ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions pull
git -C ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting pull
```

### Update Powerlevel10k
```bash
git -C ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k pull
```

### Update Homebrew Packages
```bash
brew update
brew upgrade
```

## Security Notes

- **Bitwarden Token:** The `BWS_ACCESS_TOKEN` is stored in plaintext in `.zshrc`. Consider:
  - Storing it in a `.zshrc.local` file excluded from version control
  - Using `source ~/.zshrc.local` to load sensitive data
  - Rotating tokens regularly

- **Git Credentials:** Use macOS Keychain or git credential helpers instead of storing tokens in history

- **Shell History:** By default, zsh history is stored in `~/.zsh_history`. Use `export HISTFILE=/dev/null` to disable history if working with sensitive data in specific sessions.

## Additional Resources

- [oh-my-zsh Documentation](https://github.com/ohmyzsh/ohmyzsh)
- [Powerlevel10k GitHub](https://github.com/romkatv/powerlevel10k)
- [eza — Modern ls](https://github.com/eza-community/eza)
- [bat — cat with syntax highlighting](https://github.com/sharkdp/bat)
- [ripgrep — Fast grep](https://github.com/BurntSushi/ripgrep)
- [fzf — Fuzzy finder](https://github.com/junegunn/fzf)
