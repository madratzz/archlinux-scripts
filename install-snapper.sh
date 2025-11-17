#!/bin/bash
#
# Snapper Setup Script for Arch Linux (Auto-Detects Bootloader and Init System)
# This script installs Snapper, Snap-pac, and the appropriate bootloader integration,
# only proceeding if systemd is detected.

# --- Configuration Variables ---
ROOT_CONFIG_NAME="root"
BTRFS_ROOT="/" # Path to the Btrfs subvolume root, often /
# ---

BOOTLOADER=""
INTEGRATION_PACKAGE=""
DEPLOY_COMMAND=""

echo "========================================================"
echo " Snapper Setup Script for Arch Linux (Robust Checks)"
echo "========================================================"

# Check for root permissions
if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run with root privileges (sudo)."
  exit 1
fi

# 1. Init System Detection Function (New Check)
detect_init_system() {
    echo "➡️ Checking for systemd init system..."
    # Check if the systemd executable exists and if PID 1 is systemd (reliable check)
    if [ -d "/run/systemd/system" ] && [ "$(readlink -f /sbin/init)" = "/usr/lib/systemd/systemd" ]; then
        echo "✅ Detected: systemd. Proceeding with setup."
        return 0
    else
        echo "❌ Error: systemd was not detected or is not the running init system."
        echo "   Snapper relies on systemd timers/services for automation."
        exit 1
    fi
}

# 2. Bootloader Detection Function (Existing Logic)
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
        echo "   Assuming default GRUB setup as a fallback."
        BOOTLOADER="GRUB"
        INTEGRATION_PACKAGE="grub-btrfs"
        DEPLOY_COMMAND="grub-mkconfig -o /boot/grub/grub.cfg"
    fi
}

# 3. Main Setup and Installation Function (Existing Logic)
run_snapper_setup() {
    # Check for Btrfs
    echo "➡️ Checking if root filesystem ($BTRFS_ROOT) is Btrfs..."
    if ! findmnt -t btrfs -M "$BTRFS_ROOT" > /dev/null; then
        echo "❌ Error: $BTRFS_ROOT is not mounted as a Btrfs filesystem."
        echo "This script requires Btrfs for Snapper functionality."
        exit 1
    fi
    echo "✅ Btrfs filesystem confirmed."

    # Package Installation
    echo "➡️ Installing Snapper, Btrfs tools, snap-pac, and the bootloader package ($INTEGRATION_PACKAGE)..."
    PACKAGES="snapper btrfs-progs snap-pac $INTEGRATION_PACKAGE"

    if ! pacman -S --noconfirm $PACKAGES; then
        echo "⚠️ Warning: Failed to install one or more required packages via pacman."
        echo "   The package '$INTEGRATION_PACKAGE' may be in the AUR (e.g., yay -S $INTEGRATION_PACKAGE). Please ensure it is installed manually if this fails."
        echo "   Continuing with the rest of the setup..."
    fi
    echo "✅ Required packages installed (or attempted)."

    # Create Snapper Configuration for Root (/)
    echo "➡️ Creating Snapper configuration for the root filesystem ('$ROOT_CONFIG_NAME')..."
    if [ -f "/etc/snapper/configs/$ROOT_CONFIG_NAME" ]; then
        echo "   Existing config found. Deleting it before creating a new one..."
        snapper delete-config "$ROOT_CONFIG_NAME"
    fi

    if ! snapper -c "$ROOT_CONFIG_NAME" create-config "$BTRFS_ROOT"; then
        echo "❌ Error: Failed to create Snapper configuration '$ROOT_CONFIG_NAME'."
        exit 1
    fi
    echo "✅ Snapper configuration '$ROOT_CONFIG_NAME' created."

    # Configure Snapper Settings (Tweaks)
    echo "➡️ Adjusting root config settings for better management..."
    # Reduce timeline retention to 3 monthly, 7 daily, 24 hourly
    sed -i 's/^TIMELINE_LIMIT_MONTHLY="10"$/TIMELINE_LIMIT_MONTHLY="3"/' "/etc/snapper/configs/$ROOT_CONFIG_NAME"
    sed -i 's/^TIMELINE_LIMIT_DAILY="10"$/TIMELINE_LIMIT_DAILY="7"/' "/etc/snapper/configs/$ROOT_CONFIG_NAME"
    sed -i 's/^TIMELINE_LIMIT_HOURLY="10"$/TIMELINE_LIMIT_HOURLY="24"/' "/etc/snapper/configs/$ROOT_CONFIG_NAME"
    # Ensure QGROUP is not set, as it is often not needed
    sed -i 's/^QGROUP=""$/QGROUP="none"/' "/etc/snapper/configs/$ROOT_CONFIG_NAME"
    echo "   Cleanup settings updated."

    # Create .snapshots subvolume and mount point (if not present)
    echo "➡️ Ensuring the /.snapshots subvolume is set up..."
    [ ! -d "/.snapshots" ] && mkdir -p "/.snapshots"

    # Enable Timers for Automatic Snapshots
    echo "➡️ Enabling systemd timers for automatic snapshots..."
    systemctl enable --now snapper-timeline.timer
    systemctl enable --now snapper-cleanup.timer
    echo "✅ Timeline and cleanup timers enabled and started."

    # Update Bootloader Configuration for Snapshot Booting
    echo "➡️ Regenerating $BOOTLOADER configuration for snapshot booting..."
    if [ -n "$DEPLOY_COMMAND" ]; then
        echo "   Executing: $DEPLOY_COMMAND"
        # Run the command and print a warning if it fails (often due to AUR package missing)
        if ! eval "$DEPLOY_COMMAND"; then
            echo "⚠️ Warning: The bootloader deployment command failed. This usually means the '$INTEGRATION_PACKAGE' package is missing or not configured. Please check your $BOOTLOADER installation."
        fi
    fi
    echo "✅ Bootloader configuration updated (or attempted)."
}

# --- Execution ---
detect_init_system # Run the systemd check first
detect_bootloader
echo "========================================================="

# We already exit in detect_init_system if systemd is not found,
# so we just proceed with the setup.
run_snapper_setup

echo "========================================================="
echo " Installation Complete!"
echo "========================================================="
echo "Snapper is set up to create snapshots automatically, and the $BOOTLOADER menu has been updated (if configuration was successful)."
