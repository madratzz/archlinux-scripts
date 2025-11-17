#!/bin/bash

# --- Configuration ---
# List of command-line utility packages to install from official repositories.
CLI_PACKAGES="eza fastfetch zoxide bat btop duf dust fd ripgrep tldr broot zsh fish"

# --- Functions ---

# Function to check for and refresh sudo credentials
check_and_refresh_sudo() {
    # If the user is root, proceed directly. Otherwise, prompt for sudo access.
    if [[ $(id -u) -eq 0 ]]; then
        echo "✅ Running as root. Proceeding with installation."
        return 0
    fi

    echo "🚨 This script requires elevated privileges (sudo) for installing system dependencies."

    # Run sudo -v to prompt for a password and refresh the sudo timestamp.
    if sudo -v; then
        echo "✅ Sudo credentials successfully validated. Proceeding non-interactively."
        return 0
    else
        echo "❌ Sudo access denied or command failed. Exiting."
        exit 1
    fi
}

# Function to run package manager commands (for official repositories)
run_pacman_command() {
    local command_args="$@"

    echo "Executing: sudo pacman $command_args"

    # --noconfirm flag ensures no user prompts for official packages
    if sudo pacman $command_args --noconfirm; then
        echo "🎉 Command successful."
        return 0
    else
        echo "❌ Command failed: sudo pacman $command_args"
        return 1
    fi
}

# --- Main Script Execution ---

echo "🚀 Starting installation of modern command-line tools on Arch Linux."
echo "Tools to be installed: $CLI_PACKAGES"
echo "--------------------------------------------------------"

# 1. Check for and refresh sudo credentials
check_and_refresh_sudo

# 2. Update package databases
echo "🔄 Synchronizing package databases and checking for system updates..."
run_pacman_command -Syu || { echo "Fatal: System update/sync failed. Exiting."; exit 1; }

# 3. Install all command-line utilities
echo "📦 Installing core CLI packages..."
# Using --needed prevents reinstalling packages that are already up-to-date.
# We explicitly install all tools in one command.
run_pacman_command -S --needed $CLI_PACKAGES || { echo "Fatal: Installation of CLI packages failed. Exiting."; exit 1; }

# 4. Post-Installation Note for Zsh and Fish
echo "--------------------------------------------------------"
echo "🎉 All selected tools are successfully installed!"
echo ""
echo "💡 **IMPORTANT:** Zsh and Fish are now available, but your default shell is still likely Bash."
echo "To switch your default shell to Zsh or Fish, use the 'chsh' command:"
echo "   To set Zsh: chsh -s /usr/bin/zsh"
echo "   To set Fish: chsh -s /usr/bin/fish"
echo "Remember to log out and log back in for the change to take effect."
