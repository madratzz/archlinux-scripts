#!/bin/bash

# --- Configuration ---
# Core Thunar file manager and essential plugins.
# Added gvfs (Virtual File System) and its plugins for network support:
# gvfs-smb: Enables browsing Windows shares (smb:// addresses).
# gvfs-nfs, gvfs-mtp: Adds support for NFS and MTP (mobile devices).
THUNAR_PACKAGES="thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman tumbler gvfs gvfs-smb gvfs-nfs gvfs-mtp"

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

echo "🚀 Starting installation of Thunar and core plugins on Arch Linux."
echo "--------------------------------------------------------"

# 1. Check for and refresh sudo credentials
check_and_refresh_sudo

# 2. Update package databases
echo "🔄 Synchronizing package databases and checking for system updates..."
run_pacman_command -Syu || { echo "Fatal: System update/sync failed. Exiting."; exit 1; }

# 3. Install Thunar and its plugins
echo "📦 Installing Thunar and plugins: $THUNAR_PACKAGES"
# Using --needed prevents reinstalling packages that are already up-to-date.
run_pacman_command -S --needed $THUNAR_PACKAGES || { echo "Fatal: Installation of Thunar packages failed. Exiting."; exit 1; }

echo "--------------------------------------------------------"
echo "🎉 Thunar and its core plugins are successfully installed."
echo "You can launch the file manager by running 'thunar'."
