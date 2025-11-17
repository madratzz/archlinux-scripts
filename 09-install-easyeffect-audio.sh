#!/bin/bash

# --- Configuration ---
EASYEFFECTS_PACKAGE="easyeffects"
# Recommended optional dependencies/plugins for a full experience.
OPTIONAL_PLUGINS="calf lsp-plugins-lv2 mda.lv2 zam-plugins-lv2"

# --- Root/Sudo Check Function ---
check_and_request_sudo() {
    # Check if we are already root
    if [[ $(id -u) -eq 0 ]]; then
        echo "✅ Running as root."
        return 0
    fi

    # If not root, try to execute the script again using sudo
    echo "🚨 This script requires root privileges. Requesting sudo access..."

    # Re-executes the current script using sudo. This asks the user for their password.
    if sudo -v; then
        exec sudo "$0" "$@"
    else
        echo "❌ Sudo access denied or command failed. Exiting."
        exit 1
    fi
}

# --- Main Script Execution ---

check_and_request_sudo

echo "🚀 Starting EasyEffects and plugins installation on Arch Linux..."
echo "---"

# --- Update System ---
echo "🔄 Synchronizing package databases and checking for system updates..."
# We can use -Syu here since we are root and have confirmed connectivity/permissions.
pacman -Syu --noconfirm || { echo "❌ Failed to synchronize or update package databases. Exiting."; exit 1; }

# --- Installation ---
echo "📦 Installing EasyEffects ($EASYEFFECTS_PACKAGE)..."
pacman -S --noconfirm "$EASYEFFECTS_PACKAGE" || { echo "❌ Failed to install EasyEffects. Exiting."; exit 1; }

echo "🧩 Installing key optional plugins: $OPTIONAL_PLUGINS"
# Install optional plugins. The '|| true' allows the script to continue
# even if one of the optional packages fails to install.
pacman -S --noconfirm $OPTIONAL_PLUGINS || echo "⚠️ One or more optional plugins failed to install. Continuing..."

echo "---"
echo "✅ Installation Complete."
echo "You can now launch EasyEffects."
