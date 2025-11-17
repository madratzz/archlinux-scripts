#!/bin/bash

# --- Configuration ---
AUR_PACKAGES="visual-studio-code-bin rider zed"
AUR_HELPER="yay"
BASE_DEPENDENCIES="base-devel git"

# --- Functions ---

# Function to check for and refresh sudo credentials
check_and_refresh_sudo() {
    # AUR packages MUST be built as a regular user, not root, for security.
    if [[ $(id -u) -eq 0 ]]; then
        echo "❌ ERROR: This script must be run as a regular user for AUR installation, not root. Exiting."
        exit 1
    fi

    # Run sudo -v to prompt for a password and refresh the sudo timestamp.
    # This ensures subsequent 'sudo' calls (like pacman updates) are non-interactive.
    if sudo -v; then
        echo "✅ Sudo credentials validated. Proceeding non-interactively."
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

# Function to install the yay AUR helper
install_yay() {
    echo "--- AUR Helper Installation ---"
    echo "Checking for and installing required build dependencies: $BASE_DEPENDENCIES"

    # 1. Install base dependencies for building AUR packages
    run_pacman_command -S $BASE_DEPENDENCIES || { echo "Fatal: Failed to install base dependencies. Exiting."; exit 1; }

    # 2. Check if yay folder exists, remove if necessary
    if [ -d "$AUR_HELPER" ]; then
        echo "Found existing '$AUR_HELPER' directory. Cleaning up..."
        rm -rf "$AUR_HELPER"
    fi

    # 3. Clone and build yay (must run as user)
    echo "⬇️ Cloning and building $AUR_HELPER..."
    if ! git clone "https://aur.archlinux.org/$AUR_HELPER.git"; then
        echo "❌ Failed to clone $AUR_HELPER repository. Exiting."
        exit 1
    fi

    cd "$AUR_HELPER"

    # makepkg -si --noconfirm builds and installs without prompts
    if ! makepkg -si --noconfirm; then
        echo "❌ Failed to install $AUR_HELPER. Exiting."
        cd ..
        exit 1
    fi

    cd ..

    # Clean up the cloned directory
    rm -rf "$AUR_HELPER"
    echo "✅ $AUR_HELPER successfully installed."
}

# --- Main Script Execution ---

echo "🚀 Starting installation of IDEs and text editors: ${AUR_PACKAGES// / | }"
echo "--------------------------------------------------------"

# 1. Validate and refresh sudo credentials
check_and_refresh_sudo

# 2. Update package databases
echo "🔄 Synchronizing package databases and checking for system updates..."
run_pacman_command -Syu || { echo "Fatal: System update/sync failed. Exiting."; exit 1; }

# 3. Check for and install the AUR helper
if ! command -v "$AUR_HELPER" &> /dev/null; then
    echo "⚠️ $AUR_HELPER is not installed. Installing it now..."
    install_yay
else
    echo "✅ $AUR_HELPER is already installed. Skipping installation."
fi

# 4. Install the AUR packages individually
echo "--------------------------------------------------------"
echo "📦 Installing IDEs individually using $AUR_HELPER (Non-interactive)..."

INSTALL_SUCCESS=true

# Loop through each package defined in AUR_PACKAGES
for PACKAGE in $AUR_PACKAGES; do
    echo ""
    echo "--> Attempting to install: $PACKAGE"
    # --noconfirm skips PKGBUILD review, diff review, and install confirmation.
    if "$AUR_HELPER" -S --noconfirm "$PACKAGE"; then
        echo "✅ Successfully installed $PACKAGE."
    else
        echo "❌ Installation of $PACKAGE failed. Continuing to the next package..."
        INSTALL_SUCCESS=false
    fi
done

echo "--------------------------------------------------------"
if $INSTALL_SUCCESS; then
    echo "🎉 Installation of all selected IDEs Complete!"
else
    echo "⚠️ One or more IDE installations failed. Check the logs above for details."
fi
