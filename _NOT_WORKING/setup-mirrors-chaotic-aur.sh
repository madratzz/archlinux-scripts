#!/bin/bash

# --- Configuration ---
CONFIG_FILE="/etc/pacman.conf"
MIRROR_FILE="/etc/pacman.d/mirrorlist"
# Use a new backup directory each time
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

echo "🚀 Starting repair of core Pacman mirror configuration (Final Attempt)."
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
echo "📝 **Critical Fix 1:** Writing a reliable mirror to $MIRROR_FILE to guarantee server access..."
# Overwrite the potentially empty or corrupted file with a single, known-good mirror
if echo "$DEFAULT_MIRROR" | sudo tee "$MIRROR_FILE" > /dev/null; then
    echo "✅ Temporary mirror saved."
else
    echo "❌ Failed to write to $MIRROR_FILE. Exiting."
    exit 1
fi

# 4. Ensure [core] and [extra] repos are clean in pacman.conf
echo "⚙️ **Critical Fix 2:** Cleaning up stray 'Include' lines that caused parsing errors..."

# Based on your file, we need to comment out the uncommented Include lines
# that sit under commented repository headers.

# Targeting line 86 (Include line under #[extra-testing])
echo "  -> Commenting out line 86 (stray Include under extra-testing)"
sudo sed -i '86s/^/#/' "$CONFIG_FILE"

# Targeting line 95 (Include line under #[multilib-testing])
echo "  -> Commenting out line 95 (stray Include under multilib-testing)"
sudo sed -i '95s/^/#/' "$CONFIG_FILE"

echo "✅ Configuration file cleanup complete."

# 5. Force package database synchronization
echo "--------------------------------------------------------"
echo "🔄 Forcing package database synchronization (pacman -Syy)..."
# Using -Syy forces a re-download of all repository databases.
if run_pacman_command -Syy; then
    echo "🎉 Database synchronization successful! Pacman is now fully functional."
    echo "You can now run the 'setup_chaotic_aur.sh' script to complete the setup."
else
    echo "❌ Failed to synchronize databases. If this still fails, there may be a network or DNS issue."
fi

echo "--------------------------------------------------------"
