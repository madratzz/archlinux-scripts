#!/bin/bash
#
# Steam Installation Script for Arch Linux
# Installs the Steam client and necessary 32-bit Vulkan drivers for AMD GPUs.

echo "--- Starting Steam Installation Setup ---"
echo ""

# --- 1. Check Permissions and AUR Helper ---
if [[ $EUID -ne 0 ]]; then
    echo "⚠️ This script requires 'sudo' for initial setup and package management."
    SUDO="sudo"
else
    SUDO=""
fi

# Function to install the AUR helper 'yay' if it is not found
install_yay() {
    if ! command -v yay &> /dev/null; then
        echo "🟡 'yay' (AUR Helper) not found. Installing dependencies and 'yay'..."
        $SUDO pacman -S --needed base-devel git --noconfirm

        if [ $? -ne 0 ]; then
            echo "❌ Failed to install base development tools. Exiting."
            exit 1
        fi

        # Install yay
        git clone https://aur.archlinux.org/yay.git /tmp/yay-install || { echo "❌ Failed to clone yay repository."; exit 1; }
        # Run makepkg as the current user, not root
        (cd /tmp/yay-install && makepkg -si --noconfirm) || { echo "❌ Failed to install 'yay'."; exit 1; }
        $SUDO rm -rf /tmp/yay-install
        echo "✅ 'yay' installed successfully."
    else
        echo "✅ 'yay' is already installed."
    fi
}

install_yay

# --- 2. Check for Multilib Repository (CRITICAL for 32-bit apps like Steam) ---
# Check if multilib section is uncommented in pacman.conf
MULTILIB_STATUS=$(grep -A 1 -E '^\[multilib\]' /etc/pacman.conf 2>/dev/null | grep -E '^Include' 2>/dev/null)
if [[ -z $MULTILIB_STATUS ]]; then
    echo ""
    echo "🚨 **MULTILIB REPOSITORY IS NOT ACTIVE!**"
    echo "The Steam client and 32-bit games require the [multilib] repository."
    echo "Please ensure you uncomment the following lines in /etc/pacman.conf:"
    echo "  [multilib]"
    echo "  Include = /etc/pacman.d/mirrorlist"
    echo "Then run: \`sudo pacman -Sy\` before running this script again."
    echo "Exiting now to allow configuration change."
    exit 1
fi

echo "✅ [multilib] repository appears to be enabled."
echo ""

# --- 3. Install Steam and 32-bit Drivers ---
echo "Installing Steam client and lib32-vulkan-radeon (32-bit Vulkan driver for AMD)..."

# Use yay to update system and install packages non-interactively
yay -Syu steam lib32-vulkan-radeon --noconfirm --needed --answerclean All --answerdiff None

if [ $? -ne 0 ]; then
    echo "❌ One or more package installations failed. Review the output."
    exit 1
fi

echo ""
echo "----------------------------------------"
echo "✅ Steam Installation Complete!"
echo "----------------------------------------"
echo "You can now launch Steam from your desktop environment or by typing 'steam' in the terminal."
echo "Don't forget to configure the game's compatibility layer to use the 'Proton-GE-Custom' version we installed earlier!"
