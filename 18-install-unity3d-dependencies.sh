#!/bin/bash

# --- Configuration ---
# cpio is required for unpacking Unity installer files.
# p7zip provides the 7z utility, which Unity installers often require.
DEPENDENCIES="cpio p7zip"
UNITY_SHARE_DIR="$HOME/.local/share/unity3d"

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

echo "🚀 Starting installation of Unity dependencies and setting up local directory."
echo "--------------------------------------------------------"

# 1. Check for and refresh sudo credentials
check_and_refresh_sudo

# 2. Update package databases
echo "🔄 Synchronizing package databases and checking for system updates..."
# Note: $HOME is safe to use here as the script runs as the user first, then escalates with sudo
run_pacman_command -Syu || { echo "Fatal: System update/sync failed. Exiting."; exit 1; }

# 3. Install the dependencies
echo "📦 Installing required dependencies ($DEPENDENCIES)..."
run_pacman_command -S $DEPENDENCIES || { echo "Fatal: Installation of dependencies failed. Exiting."; exit 1; }

# 4. Create the required directory
echo "📁 Checking for and creating the Unity share directory: $UNITY_SHARE_DIR"

# Use 'mkdir -p' to create the directory only if it doesn't exist, and create parents if necessary.
# We don't use sudo here, as this is a user-local directory ($HOME).
if mkdir -p "$UNITY_SHARE_DIR"; then
    echo "✅ Directory created/verified: $UNITY_SHARE_DIR"
else
    echo "❌ Failed to create directory: $UNITY_SHARE_DIR. Check user permissions."
    exit 1
fi

echo "--------------------------------------------------------"
echo "🎉 Setup for Unity is complete. cpio, 7z (via p7zip), and the share directory are ready."
