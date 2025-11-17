#!/bin/bash
#
# OpenRGB Installation Script for Arch Linux
# Installs OpenRGB from the AUR using the 'yay' helper.

echo "--- Starting OpenRGB Installation Setup ---"
echo ""

# --- 1. Check Permissions and AUR Helper ---
if [[ $EUID -ne 0 ]]; then
    # We don't need root for yay installation/running, but we check for sudo setup
    SUDO="sudo"
else
    # Do not run yay as root
    SUDO=""
fi

# Function to install the AUR helper 'yay' if it is not found
install_yay() {
    if ! command -v yay &> /dev/null; then
        echo "🟡 'yay' (AUR Helper) not found. Installing dependencies and 'yay'..."

        # Install base dependencies needed for compiling AUR packages
        $SUDO pacman -S --needed base-devel git --noconfirm

        if [ $? -ne 0 ]; then
            echo "❌ Failed to install base development tools. Exiting."
            exit 1
        fi

        # Install yay (run as a normal user if possible)
        git clone https://aur.archlinux.org/yay.git /tmp/yay-install || { echo "❌ Failed to clone yay repository."; exit 1; }
        (cd /tmp/yay-install && makepkg -si --noconfirm) || { echo "❌ Failed to install 'yay'."; exit 1; }
        $SUDO rm -rf /tmp/yay-install
        echo "✅ 'yay' installed successfully."
    else
        echo "✅ 'yay' is already installed."
    fi
}

install_yay

# --- 2. Install OpenRGB ---
echo ""
echo "Installing stable 'openrgb' from the AUR..."
echo "Note: If you want the latest development version, you could use 'openrgb-git' instead."

# Use yay to update system and install the openrgb package non-interactively
# OpenRGB handles installing necessary udev rules during this process.
yay -Syu openrgb --noconfirm --needed --answerclean All --answerdiff None

if [ $? -ne 0 ]; then
    echo "❌ OpenRGB installation failed. Review the output."
    exit 1
fi

echo ""
echo "----------------------------------------"
echo "✅ OpenRGB Installation Complete!"
echo "----------------------------------------"
echo "⚠️ **IMPORTANT: REBOOT REQUIRED** ⚠️"
echo "OpenRGB requires special **udev rules** to access your RGB hardware without root permissions."
echo "These rules were installed, but you must **reboot your system** for them to take effect."
echo "After rebooting, you can run OpenRGB from your application launcher."
