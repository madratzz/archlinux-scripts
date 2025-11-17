#!/bin/bash
#
# Snapper Setup Script for Arch Linux (Auto-Detects Bootloader and Init System)
#
# FULLY IDEMPOTENT: Ensures safe re-runs by checking for existing files,
# Btrfs subvolumes, and configuration settings before making changes.
#

# --- Configuration Variables ---
ROOT_CONFIG_NAME="root"
BTRFS_ROOT="/" # Path to the Btrfs subvolume root, often /
# ---

BOOTLOADER=""
INTEGRATION_PACKAGE=""
DEPLOY_COMMAND=""

echo "========================================================"
echo " Snapper Setup Script (Core Installation as Root)"
echo "========================================================"

# Check for root permissions
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run with root privileges (sudo)."
    exit 1
fi

# Determine the user who invoked sudo for later privilege dropping
NON_ROOT_USER="$SUDO_USER"
if [ -z "$NON_ROOT_USER" ]; then
    echo "❌ Error: SUDO_USER environment variable is not set. Are you running this script using 'sudo'?"
    exit 1
fi
echo "✅ Original user detected: $NON_ROOT_USER. Will use this user for AUR installation."

# 1. Init System Detection Function (Idempotent by nature)
detect_init_system() {
    echo "➡️ Checking for systemd init system..."
    if [ -d "/run/systemd/system" ] && [ "$(readlink -f /sbin/init)" = "/usr/lib/systemd/systemd" ]; then
        echo "✅ Detected: systemd."
        return 0
    else
        echo "❌ Error: systemd was not detected or is not the running init system."
        echo "    Snapper relies on systemd timers/services for automation."
        exit 1
    fi
}

# 2. Bootloader Detection Function (Idempotent by nature)
detect_bootloader() {
    echo "➡️ Detecting active bootloader configuration..."

    if [ -f "/etc/default/grub" ]; then
        BOOTLOADER="GRUB"
        INTEGRATION_PACKAGE="grub-btrfs"
        DEPLOY_COMMAND="grub-mkconfig -o /boot/grub/grub.cfg"
        echo "✅ Detected: GRUB. Will install '$INTEGRATION_PACKAGE'."
    elif [ -f "/boot/limine.cfg" ]; then
        BOOTLOADER="LIMINE"
        INTEGRATION_PACKAGE="limine-btrfs"
        DEPLOY_COMMAND="liminectl deploy"
        echo "✅ Detected: Limine. Will install '$INTEGRATION_PACKAGE'."
    else
        echo "❌ Could not reliably detect GRUB or Limine configuration files."
        echo "    Assuming default GRUB setup as a fallback."
        BOOTLOADER="GRUB"
        INTEGRATION_PACKAGE="grub-btrfs"
        DEPLOY_COMMAND="grub-mkconfig -o /boot/grub/grub.cfg"
    fi
}

# 3. AUR Package Installation Function (Idempotent via AUR helper flags)
install_aur_package() {
    local package_name="snapper-tools"
    echo "--------------------------------------------------------"
    echo "➡️ POST-STEP: Attempting to install AUR package: $package_name"

    local aur_command=""
    if command -v yay &> /dev/null; then
        echo "    Using 'yay' to install $package_name (Running as user $NON_ROOT_USER)..."
        aur_command="yay -S --noconfirm --needed $package_name"
    elif command -v paru &> /dev/null; then
        echo "    Using 'paru' to install $package_name (Running as user $NON_ROOT_USER)..."
        aur_command="paru -S --noconfirm --needed --batch --skipreview $package_name"
    else
        echo "⚠️ Warning: No AUR helper (yay or paru) detected on the system."
        echo "    To get the full user experience, please manually install '$package_name' from the AUR later."
        echo "--------------------------------------------------------"
        return 1
    fi

    # Execute the AUR command as the unprivileged user
    if [ -n "$aur_command" ]; then
        echo "    Executing command as user $NON_ROOT_USER: $aur_command"

        if ! su - "$NON_ROOT_USER" -c "$aur_command"; then
            echo "========================================================"
            echo "❌ AUR Helper Failure Detected (Common TTY/Password Error)"
            echo "--------------------------------------------------------"
            echo "This failure usually happens because the AUR helper (yay/paru) requires"
            echo "your user's password for the final installation step, but running it"
            echo "non-interactively via 'su' prevents the password prompt."
            echo ""
            echo "✅ **Core Snapper Setup is COMPLETE.**"
            echo "    The utility package was the only step that failed."
            echo "    Please install the utility manually by running this command as **$NON_ROOT_USER**:"
            echo ""
            echo "    $aur_command"
            echo "========================================================"
            return 1
        else
            echo "✅ '$package_name' installed successfully by user $NON_ROOT_USER."
            return 0
        fi
    fi
}


# 4. Main Setup and Installation Function - RUNS AS ROOT
run_snapper_setup() {
    # Check for Btrfs (Crucial prerequisite check)
    echo "➡️ Checking if root filesystem ($BTRFS_ROOT) is Btrfs..."
    if ! findmnt -t btrfs -M "$BTRFS_ROOT" > /dev/null; then
        echo "❌ Error: $BTRFS_ROOT is not mounted as a Btrfs filesystem."
        echo "This script requires Btrfs for Snapper functionality."
        exit 1
    fi
    echo "✅ Btrfs filesystem confirmed."

    # Package Installation (Official Repos) - Idempotent via pacman --needed
    echo "➡️ Installing Snapper, Btrfs tools, snap-pac, and the bootloader package ($INTEGRATION_PACKAGE)..."
    PACKAGES="snapper btrfs-progs snap-pac $INTEGRATION_PACKAGE"

    if ! pacman -S --noconfirm --needed $PACKAGES; then
        echo "⚠️ Warning: Failed to install one or more required packages via pacman. Continuing with setup..."
    fi
    echo "✅ Required official packages installed (or attempted)."

    # --- BTRFS .snapshots CONFLICT RESOLUTION (HIGHLY IDEMPOTENT) ---
    echo "➡️ Pre-flight check: Ensuring /.snapshots is ready for Snapper..."

    # 1. Check if a directory named .snapshots exists
    if [ -d "/.snapshots" ]; then
        # 2. Check if it is a Btrfs subvolume.
        if ! btrfs subvolume list -t -o / | grep -q "/.snapshots$"; then
            echo "⚠️ Conflict found: /.snapshots exists but is a regular directory (not a subvolume)."
            echo "    Attempting to delete the empty directory..."

            if rmdir "/.snapshots" 2>/dev/null; then
                echo "✅ Conflicting directory /.snapshots removed."
            else
                echo "❌ Error: Could not remove conflicting /.snapshots directory. It may not be empty."
                echo "    Please manually remove it and re-run the script."
                exit 1 # Exit if the conflict cannot be resolved automatically
            fi
        else
            echo "✅ /.snapshots is already a Btrfs subvolume. Proceeding."
        fi
    fi

    # 3. Ensure the /.snapshots subvolume exists. (Creates if necessary)
    if ! btrfs subvolume list -t -o / | grep -q "/.snapshots$"; then
        echo "➡️ Creating missing Btrfs subvolume /.snapshots..."
        if ! btrfs subvolume create /.snapshots; then
            echo "❌ Fatal Error: Could not create Btrfs subvolume /.snapshots."
            exit 1
        fi
        echo "✅ Btrfs subvolume /.snapshots created."
    fi
    # --- END BTRFS CONFLICT RESOLUTION ---

    # Create Snapper Configuration for Root (/)
    echo "➡️ Checking Snapper configuration for the root filesystem ('$ROOT_CONFIG_NAME')..."
    CONFIG_FILE="/etc/snapper/configs/$ROOT_CONFIG_NAME"

    if [ -f "$CONFIG_FILE" ]; then
        echo "✅ Existing configuration file found at $CONFIG_FILE. Skipping creation."
    else
        echo "    No existing config file found. Creating new configuration..."

        # Attempt to create config (may fail due to internal Btrfs metadata mismatch)
        if ! snapper -c "$ROOT_CONFIG_NAME" create-config "$BTRFS_ROOT"; then
            echo "⚠️ Warning: snapper create-config failed (likely 'config already exists' internal error)."

            # If the command failed AND the file is still missing, we manually create a minimal config
            if [ ! -f "$CONFIG_FILE" ]; then
                echo "    Attempting to manually create minimal config file to resolve internal mismatch..."
                # Minimal settings needed for Snapper to recognize the internal config
                printf 'SUBVOLUME="/"\nFSTYPE="btrfs"\n' | tee "$CONFIG_FILE" > /dev/null
                echo "✅ Minimal config file created."
            else
                echo "✅ Snapper configuration file created (check file contents)."
            fi
        else
            echo "✅ Snapper configuration '$ROOT_CONFIG_NAME' created."
        fi
    fi

    # Configure Snapper Settings (Tweaks) - IDEMPOTENT BY CHECKING DESIRED VALUE
    echo "➡️ Adjusting root config settings for better management..."

    # Helper function to set or replace a config line
    set_config_value() {
        local key="$1"
        local value="$2"
        local file="$3"

        # If the desired value is not present, set it
        if ! grep -q "^$key=\"$value\"$" "$file"; then
            # Replace existing line or append if not found
            if grep -q "^$key=" "$file"; then
                # Replace existing line using sed
                sed -i -e "/^$key=/c\\$key=\"$value\"" "$file"
            else
                # Append new line
                echo "$key=\"$value\"" >> "$file"
            fi
            echo "    - Updated $key limit."
        fi
    }

    set_config_value "TIMELINE_LIMIT_MONTHLY" "3" "$CONFIG_FILE"
    set_config_value "TIMELINE_LIMIT_DAILY" "7" "$CONFIG_FILE"
    set_config_value "TIMELINE_LIMIT_HOURLY" "24" "$CONFIG_FILE"
    set_config_value "QGROUP" "" "$CONFIG_FILE"

    echo "    Cleanup settings adjusted (or confirmed) based on desired values."

    # Enable Timers for Automatic Snapshots - Idempotent via systemctl
    echo "➡️ Enabling systemd timers for automatic snapshots..."
    systemctl enable --now snapper-timeline.timer
    systemctl enable --now snapper-cleanup.timer
    echo "✅ Timeline and cleanup timers enabled and started."

    # Update Bootloader Configuration for Snapshot Booting - Idempotent to run every time
    echo "➡️ Regenerating $BOOTLOADER configuration for snapshot booting..."
    if [ -n "$DEPLOY_COMMAND" ]; then
        echo "    Executing: $DEPLOY_COMMAND"
        if ! eval "$DEPLOY_COMMAND"; then
            echo "⚠️ Warning: Bootloader deployment command failed. Check if '$INTEGRATION_PACKAGE' is installed and configured correctly."
        fi
    fi
    echo "✅ Bootloader configuration updated (or attempted)."
}

# --- Execution ---
detect_init_system
detect_bootloader

# Run the core setup first (Requires Root)
echo "========================================================="
echo " Starting Core Snapper/Snap-pac Setup (Running as Root)..."
echo "========================================================="
run_snapper_setup

# Run the AUR installation as the post-step (Drops Privileges)
echo "========================================================="
echo " Starting Post-Setup: AUR Tools Installation (Dropping privileges to $NON_ROOT_USER)"
echo "========================================================="
install_aur_package

echo "========================================================="
echo " Installation Complete!"
echo "--------------------------------------------------------"
echo "You can now check your snapshot list with: snapper list"
echo "If snapper-tools installed successfully, run: snapper-tools"
