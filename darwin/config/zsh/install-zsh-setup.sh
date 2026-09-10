#!/bin/bash
#
# install-zsh-setup.sh
# Automated installation script for zsh configuration on macOS
# Sets up oh-my-zsh, Powerlevel10k, plugins, and CLI tools

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=== Zsh Setup Installer ===${NC}\n"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script is designed for macOS only${NC}"
    exit 1
fi

# Function to print status messages
print_status() {
    echo -e "${BLUE}→${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Step 1: Install Homebrew if not present
if ! command -v brew &> /dev/null; then
    print_status "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for M1/M2 Macs
    if [[ "$(uname -m)" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    print_success "Homebrew installed"
else
    print_success "Homebrew already installed"
fi

# Ensure Homebrew is in PATH
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Step 2: Install CLI tools and utilities
print_status "Installing CLI tools..."

TOOLS=(
    "eza:Modern ls replacement"
    "bat:Syntax-highlighted cat"
    "ripgrep:Fast grep replacement"
    "fzf:Fuzzy finder"
    "bitwarden-cli:Bitwarden CLI tool"
    "fastfetch:System info display"
    "python@3.14:Python 3.14"
)

for tool_spec in "${TOOLS[@]}"; do
    tool="${tool_spec%%:*}"
    description="${tool_spec#*:}"

    if brew list "$tool" &>/dev/null; then
        print_success "$description already installed"
    else
        print_status "Installing $description..."
        brew install "$tool" || print_warning "Failed to install $tool"
    fi
done

# Step 3: Install or upgrade oh-my-zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    print_success "oh-my-zsh already installed"
else
    print_status "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    print_success "oh-my-zsh installed"
fi

# Step 4: Install Powerlevel10k
POWERLEVEL10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [[ -d "$POWERLEVEL10K_DIR" ]]; then
    print_status "Updating Powerlevel10k..."
    git -C "$POWERLEVEL10K_DIR" pull --quiet
    print_success "Powerlevel10k updated"
else
    print_status "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$POWERLEVEL10K_DIR" 2>/dev/null
    print_success "Powerlevel10k installed"
fi

# Step 5: Install zsh plugins
print_status "Installing zsh plugins..."

declare -A PLUGINS=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
)

for plugin_name in "${!PLUGINS[@]}"; do
    plugin_url="${PLUGINS[$plugin_name]}"
    plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin_name"

    if [[ -d "$plugin_dir" ]]; then
        print_status "Updating $plugin_name..."
        git -C "$plugin_dir" pull --quiet
        print_success "$plugin_name updated"
    else
        print_status "Installing $plugin_name..."
        git clone "$plugin_url" "$plugin_dir" 2>/dev/null
        print_success "$plugin_name installed"
    fi
done

# Step 6: Backup existing shell configuration
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
    BACKUP_FILE="$HOME/.zshrc.backup.$(date +%s)"
    print_status "Backing up existing .zshrc to $BACKUP_FILE"
    cp "$HOME/.zshrc" "$BACKUP_FILE"
    print_success "Backup created"
fi

if [[ -f "$HOME/.zprofile" && ! -L "$HOME/.zprofile" ]]; then
    BACKUP_FILE="$HOME/.zprofile.backup.$(date +%s)"
    print_status "Backing up existing .zprofile to $BACKUP_FILE"
    cp "$HOME/.zprofile" "$BACKUP_FILE"
    print_success "Backup created"
fi

# Step 7: Link configuration files
print_status "Linking configuration files..."

if [[ -L "$HOME/.zshrc" ]]; then
    rm "$HOME/.zshrc"
fi
ln -sf "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
print_success ".zshrc linked"

if [[ -L "$HOME/.zprofile" ]]; then
    rm "$HOME/.zprofile"
fi
ln -sf "$SCRIPT_DIR/.zprofile" "$HOME/.zprofile"
print_success ".zprofile linked"

# Step 8: Set zsh as default shell
if [[ "$SHELL" != *"zsh"* ]]; then
    print_status "Setting zsh as default shell..."
    chsh -s "$(which zsh)"
    print_success "Default shell set to zsh"
else
    print_success "Zsh is already the default shell"
fi

# Step 9: Offer to install Nerd Font
echo ""
print_status "For best results with Powerlevel10k icons, install a Nerd Font:"
print_status "  brew install font-meslo-lg-nerd-font"
print_status "  Then update your terminal font settings to use 'MesloLGS NF'"

# Step 10: Verification
echo ""
print_status "Verifying installation..."

CHECKS=(
    ["zsh version"]="zsh --version"
    ["oh-my-zsh"]="test -d ~/.oh-my-zsh && echo 'Installed' || echo 'Not found'"
    ["Powerlevel10k"]="test -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k && echo 'Installed' || echo 'Not found'"
    ["eza"]="eza --version"
    ["bat"]="bat --version"
    ["ripgrep"]="rg --version | head -1"
    ["fzf"]="fzf --version"
    ["bitwarden"]="bw --version"
    ["fastfetch"]="fastfetch --version"
)

VERIFICATION_PASSED=true

for check_name in "${!CHECKS[@]}"; do
    check_cmd="${CHECKS[$check_name]}"
    if eval "$check_cmd" &>/dev/null; then
        print_success "$check_name"
    else
        print_warning "$check_name (not available or check failed)"
        VERIFICATION_PASSED=false
    fi
done

echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}\n"

if [[ "$VERIFICATION_PASSED" == true ]]; then
    print_success "All components installed successfully!"
else
    print_warning "Some components may not be available. Review messages above."
fi

echo ""
print_status "Next steps:"
echo "  1. Restart your terminal or run: source ~/.zshrc"
echo "  2. Run: p10k configure (to customize Powerlevel10k)"
echo "  3. Install a Nerd Font for proper icon display"
echo "  4. Review ~/.zshrc and ~/.zprofile to customize as needed"
echo ""
print_status "For more information, see the README.md in this directory"
