#!/bin/bash

# --- Configuration ---
QPWGRAPH_PACKAGE="qpwgraph"

# --- Functions ---

# Function to check for and refresh sudo credentials
check_and_refresh_sudo() {
    # Check if we are already root (UID 0)
    if [[ $(id -u) -eq 0 ]]; then
        echo "✅ Running as root. Proceeding with installation."
        return 0
    fi

    echo "🚨 This script requires elevated privileges (sudo)."

    # Run sudo -v to prompt for a password and reset/refresh the sudo timestamp.
    # This prevents the user from being prompted again for a short duration
    # (default 15 minutes), covering subsequent commands in the script.
    if sudo -v; then
        echo "✅ Sudo credentials successfully validated and refreshed. Proceeding..."
        return 0
    else
        echo "❌ Sudo access denied or command failed. Exiting."
        exit 1
    fi
}

# Function to run package manager commands
run_pacman_command() {
    local command_args="$@"

    # We use sudo here because the check_and_refresh_sudo call ensures the
    # user is authenticated, making subsequent sudo calls seamless.
    echo "Executing: sudo pacman $command_args"

    if sudo pacman $command_args --noconfirm; then
        echo "🎉 Command successful."
        return 0
    else
        echo "❌ Command failed: sudo pacman $command_args"
        return 1
    fi
}

# --- Main Script Execution ---

echo "🚀 Starting installation of $QPWGRAPH_PACKAGE on Arch Linux..."
echo "--------------------------------------------------------"

# 1. Check for and refresh sudo credentials
check_and_refresh_sudo

# 2. Update package databases
echo "🔄 Synchronizing package databases and checking for system updates..."
run_pacman_command -Syu || { echo "Fatal: System update/sync failed. Exiting."; exit 1; }

# 3. Install the package and its required dependencies
echo "📦 Installing $QPWGRAPH_PACKAGE (PipeWire Graph Qt GUI Interface)..."
# pacman automatically resolves and installs all required dependencies (like qt6-base, libpipewire, etc.)
run_pacman_command -S "$QPWGRAPH_PACKAGE" || { echo "Fatal: Installation of $QPWGRAPH_PACKAGE failed. Exiting."; exit 1; }

echo "--------------------------------------------------------"
echo "✅ Installation Complete."
echo "You can now run '$QPWGRAPH_PACKAGE' to manage your PipeWire connections."
