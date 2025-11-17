#!/bin/bash
#
# Script to install LazyVim configuration for Neovim (nvim) and required Language Servers (LSPs).
#
# PREREQUISITES:
# 1. Neovim (nvim) version 0.9.0 or higher MUST be installed (or the script will attempt to install it).
# 2. Git must be installed.
# 3. For LSP support, the language's core tooling must be installed on your system:
#    - Rust: 'cargo' (via rustup)
#    - Python: 'python3'
#    - C#: 'dotnet'

# --- Variables ---
NVIM_CONFIG_DIR="${HOME}/.config/nvim"
NVIM_LOCAL_SHARE_DIR="${HOME}/.local/share/nvim"
BACKUP_DIR="${HOME}/.config/nvim_backup_$(date +%Y%m%d%H%M%S)"

# --- Functions ---

# Check if a command exists
command_exists () {
    command -v "$1" &> /dev/null
}

# Function to install Neovim
install_nvim() {
    echo ""
    echo "--- Attempting to install Neovim ---"

    if command_exists pacman; then
        echo "Detected Arch Linux. Using pacman to install Neovim."
        # -Syu updates the system packages and installs neovim
        sudo pacman -Syu --noconfirm neovim
    elif command_exists apt; then
        echo "Detected Debian/Ubuntu. Using apt to install Neovim."
        sudo apt update
        sudo apt install -y neovim
    elif command_exists dnf; then
        echo "Detected Fedora/RHEL. Using dnf to install Neovim."
        sudo dnf install -y neovim
    elif command_exists brew; then
        echo "Detected macOS/Linux (Homebrew). Using brew to install Neovim."
        brew install neovim
    elif command_exists snap; then
        echo "Detected system supporting Snap. Using snap to install Neovim."
        sudo snap install nvim --classic
    else
        echo "❌ Cannot determine package manager. Please install Neovim (v0.9.0 or higher) manually."
        echo "See installation instructions here: https://github.com/neovim/neovim/wiki/Installing-Neovim"
        exit 1
    fi

    # Post-install check for required version
    if command_exists nvim; then
        check_nvim_version 1 # Run version check silently after installation attempt
    else
        echo "❌ Neovim installation failed. Please check the output or install it manually. Exiting."
        exit 1
    fi
}

# Check for Neovim and version
check_nvim_version() {
    local post_install_mode=${1:-0}
    local required_version="0.9.0"

    # Helper function for version comparison
    function version_less_than() {
        printf '%s\n' "$2" "$1" | sort -V | head -n 1 | grep -q "$1"
    }

    if ! command_exists nvim; then
        if [ "$post_install_mode" -eq 0 ]; then
            echo "❌ Neovim ('nvim') command not found."
            install_nvim
            return
        else
            # This handles the case where post_install_mode is 1 but nvim still doesn't exist
            echo "❌ Neovim still not found after installation attempt. Exiting."
            exit 1
        fi
    fi

    local version=$(nvim --version | head -n 1 | awk '{print $2}' | sed 's/v//')

    if version_less_than "$version" "$required_version"; then
        echo "⚠️ Neovim installed (v$version) is less than the required minimum ($required_version)."
        if [ "$post_install_mode" -eq 0 ]; then
            echo "Attempting to install a newer version, but manual installation may be required on older systems."
            install_nvim # Attempt to install/upgrade
            return
        else
            echo "Please manually install a modern version (v0.9.0+) or use the AppImage. Exiting."
            exit 1
        fi
    else
        echo "✅ Neovim (v$version) check passed."
    fi
}


# Function to check for dependency and install a single LSP package via Mason
install_lsp() {
    local lang_name="$1"
    local dependency_command="$2"
    local mason_package="$3"

    echo ""
    echo "--- Checking for $lang_name ($mason_package) ---"
    if command_exists "$dependency_command"; then
        echo "✅ Dependency '$dependency_command' found."
        echo "⬇️ Installing $mason_package via Mason (Non-Interactive)..."

        # Use nvim in headless mode to run the MasonInstall command
        if nvim --headless "+MasonInstall $mason_package" "+qa"; then
            echo "✅ $mason_package installed successfully."
        else
            echo "❌ Failed to install $mason_package. You may need to run 'nvim' and then ':Mason' to check manually."
        fi
    else
        echo "⚠️ Dependency '$dependency_command' not found."
        echo "Skipping $mason_package installation."
        echo "To enable $lang_name support, please install '$dependency_command' first and then run ':MasonInstall $mason_package' inside nvim."
    fi
}

# --- Main Installation Steps ---

echo "--- LazyVim & Language Server Installation Starting ---"

# 1. Check prerequisites (including Neovim, with auto-install logic)
check_nvim_version

if ! command_exists git; then
    echo "❌ Git not found. Git is required to clone LazyVim. Exiting."
    exit 1
fi
echo "✅ Git check passed."

# 2. Backup existing configuration
if [ -d "$NVIM_CONFIG_DIR" ]; then
    echo "📦 Found existing Neovim config at $NVIM_CONFIG_DIR."
    echo "Moving existing config to: $BACKUP_DIR"
    mv "$NVIM_CONFIG_DIR" "$BACKUP_DIR"

    if [ -d "$NVIM_LOCAL_SHARE_DIR" ]; then
        echo "🗑️ Removing existing share/cache data at $NVIM_LOCAL_SHARE_DIR (Recommended for clean install)."
        rm -rf "$NVIM_LOCAL_SHARE_DIR"
    fi
else
    echo "✅ No existing Neovim config found. Proceeding."
fi

# 3. Clone the LazyVim starter template
echo ""
echo "⬇️ Cloning LazyVim Starter Template..."
if git clone https://github.com/LazyVim/starter.git "$NVIM_CONFIG_DIR"; then
    echo "✅ LazyVim cloned successfully."
else
    echo "❌ Failed to clone LazyVim repository. Check your network connection. Exiting."
    exit 1
fi

# 4. Remove the .git folder to make it an independent config
rm -rf "$NVIM_CONFIG_DIR/.git"

# 5. Launch Neovim to trigger initial plugin install (Mason, treesitter, etc.)
echo ""
echo "🚀 Starting Neovim for initial plugin install..."
echo "This will download the core LazyVim plugins. Please wait for the process to complete."
nvim --headless "+Lazy install" "+qa" || { echo "❌ Initial LazyVim installation failed."; exit 1; }
echo "✅ Core plugins installed."

# 6. Install specific Language Servers via Mason
echo ""
echo "=================================================="
echo "    Starting Language Server Installation"
echo "=================================================="

# Rust LSP: requires 'cargo' to be installed
install_lsp "Rust" "cargo" "rust-analyzer"

# Python LSP: requires 'python3' (or 'python') to be installed
install_lsp "Python" "python3" "pyright"

# C# LSP: requires 'dotnet' to be installed
install_lsp "C#" "dotnet" "csharp-language-server"

# --- Final Instructions ---
echo ""
echo "--- Installation Complete! ---"
echo "To start Neovim with LazyVim, just type: nvim"
echo "Your old configuration (if any) was backed up to: $BACKUP_DIR"
echo "If any LSP installation failed, open nvim and run ':Mason' to troubleshoot or manually install the package."
