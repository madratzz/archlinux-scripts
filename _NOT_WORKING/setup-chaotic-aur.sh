#!/bin/bash

# --- Configuration ---
CONFIG_FILE="/etc/pacman.conf"
MIRROR_FILE="/etc/pacman.d/mirrorlist"
BACKUP_DIR="/var/tmp/pacman_backup_$(date +%Y%m%d_%H%M%S)"

# A reliable, widely used Arch Linux mirror to use as a temporary fix
DEFAULT_MIRROR="Server = https://mirror.leaseweb.com/archlinux/\$repo/os/\$arch"

# --- Functions ---

# Function to check for and refresh sudo credentials
check_and_refresh_sudo() {
    if [[ $(id -u) -eq 0 ]]; then
        echo "✅ Running as root. Proceeding."
        return 0
    fi

    echo "🚨 This script requires elevated privileges (sudo) to modify system configuration."

    if sudo -v; then
        echo "✅ Sudo credentials validated. Proceeding non-interactively."
        return 0
    else
        echo "❌ Sudo access denied or command failed. Exiting."
        exit 1
    fi
}

# Function to run package manager commands
run_pacman_command() {
    local command_args="$@"

    echo "Executing: sudo pacman $command_args"

    # We use --noconfirm and --needed for safety
    if sudo pacman $command_args --noconfirm --needed; then
        return 0
    else
        echo "❌ Command failed: sudo pacman $command_args"
        return 1
    fi
}

# --- Main Script Execution ---

echo "🚀 Starting repair of core Pacman mirror configuration."
echo "--------------------------------------------------------"

# 1. Check for and refresh sudo credentials
check_and_refresh_sudo

# 2. Backup existing configuration
echo "💾 Creating backup of existing configuration files in $BACKUP_DIR..."
sudo mkdir -p "$BACKUP_DIR"
if [ -f "$CONFIG_FILE" ]; then
    sudo cp "$CONFIG_FILE" "$BACKUP_DIR/"
fi
if [ -f "$MIRROR_FILE" ]; then
    sudo cp "$MIRROR_FILE" "$BACKUP_DIR/"
fi
echo "✅ Configuration files backed up."

# 3. Create a temporary, working mirrorlist
echo "📝 Writing a temporary mirrorlist to $MIRROR_FILE with a reliable mirror..."
# Overwrite the potentially empty or corrupted file with a single, known-good mirror
if echo "$DEFAULT_MIRROR" | sudo tee "$MIRROR_FILE" > /dev/null; then
    echo "✅ Temporary mirror saved."
else
    echo "❌ Failed to write to $MIRROR_FILE. Exiting."
    exit 1
fi

# 4. Ensure [core] and [extra] repos are uncommented in pacman.conf
echo "⚙️ Ensuring [core] and [extra] repositories are enabled in $CONFIG_FILE..."
# Use sed to safely ensure the [core] and [extra] blocks are uncommented
sudo sed -i 's/^#\[core\]/\[core\]/' "$CONFIG_FILE"
sudo sed -i '/^\[core\]/,/^#Include/ s/^#Include = /Include = /' "$CONFIG_FILE"

sudo sed -i 's/^#\[extra\]/\[extra\]/' "$CONFIG_FILE"
sudo sed -i '/^\[extra\]/,/^#Include/ s/^#Include = /Include = /' "$CONFIG_FILE"

echo "✅ Core repositories configuration verified."

# 5. Force package database synchronization
echo "--------------------------------------------------------"
echo "🔄 Forcing package database synchronization (pacman -Syy)..."
# Using -Syy forces a re-download of all repository databases.
if run_pacman_command -Syy; then
    echo "🎉 Database synchronization successful! Pacman is now working."
    echo "You should now be able to run the 'setup_chaotic_aur.sh' script without issues."
else
    echo "❌ Failed to synchronize databases. Please check network connection and DNS."
fi

echo "--------------------------------------------------------"
