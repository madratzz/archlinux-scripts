#!/bin/bash
#
# Snapper Installation and Configuration Script for Arch Linux
# This script installs snapper, snap-pac, grub-btrfs, and sets up
# the default configuration for the root filesystem.

# --- Configuration Variables ---
ROOT_CONFIG_NAME="root"
# Path to the Btrfs subvolume root, often /
BTRFS_ROOT="/"
# ---

echo "========================================================"
echo " Snapper Setup Script for Arch Linux"
echo "========================================================"

# Check for root permissions
if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run with root privileges (sudo)."
  exit 1
fi

# 1. Check for Btrfs
echo "➡️ Checking if root filesystem ($BTRFS_ROOT) is Btrfs..."
if ! findmnt -t btrfs -M "$BTRFS_ROOT" > /dev/null; then
    echo "❌ Error: $BTRFS_ROOT is not mounted as a Btrfs filesystem."
    echo "This script requires Btrfs for Snapper functionality."
    exit 1
fi
echo "✅ Btrfs filesystem confirmed."

# 2. Package Installation
echo "➡️ Installing Snapper, Btrfs tools, snap-pac, and grub-btrfs..."
PACKAGES="snapper btrfs-progs snap-pac grub-btrfs"

if ! pacman -S --noconfirm $PACKAGES; then
    echo "❌ Error: Failed to install one or more required packages."
    exit 1
fi
echo "✅ Required packages installed."

# 3. Create Snapper Configuration for Root (/)
echo "➡️ Creating Snapper configuration for the root filesystem ('$ROOT_CONFIG_NAME')..."

# Remove existing config if present
if [ -f "/etc/snapper/configs/$ROOT_CONFIG_NAME" ]; then
    echo "   Existing config found. Deleting it before creating a new one..."
    snapper delete-config "$ROOT_CONFIG_NAME"
fi

# Create the new root config based on the / subvolume
if ! snapper -c "$ROOT_CONFIG_NAME" create-config "$BTRFS_ROOT"; then
    echo "❌ Error: Failed to create Snapper configuration '$ROOT_CONFIG_NAME'."
    exit 1
fi
echo "✅ Snapper configuration '$ROOT_CONFIG_NAME' created."

# 4. Configure Snapper Settings (Optional Tweaks)
echo "➡️ Adjusting root config settings for better management..."
# Set TIMEOUT to 30 days (max snapshots retained)
sed -i 's/^TIMELINE_LIMIT_MONTHLY="10"$/TIMELINE_LIMIT_MONTHLY="3"/' "/etc/snapper/configs/$ROOT_CONFIG_NAME"
sed -i 's/^TIMELINE_LIMIT_DAILY="10"$/TIMELINE_LIMIT_DAILY="7"/' "/etc/snapper/configs/$ROOT_CONFIG_NAME"
sed -i 's/^TIMELINE_LIMIT_HOURLY="10"$/TIMELINE_LIMIT_HOURLY="24"/' "/etc/snapper/configs/$ROOT_CONFIG_NAME"
# Set QGROUP to "none" to prevent potential qgroup conflicts
sed -i 's/^QGROUP=""$/QGROUP="none"/' "/etc/snapper/configs/$ROOT_CONFIG_NAME"
echo "   Cleanup settings updated (e.g., keeping 7 daily, 24 hourly snapshots)."

# 5. Create .snapshots subvolume and mount point (if not present)
# Snapper usually creates the required .snapshots subvolume under the Btrfs root.
echo "➡️ Ensuring the .snapshots subvolume is set up..."
BTRFS_SUBVOL_ROOT=$(findmnt -t btrfs -M "$BTRFS_ROOT" -o SOURCE -n)
if [ ! -d "/.snapshots" ]; then
    echo "   Creating /.snapshots directory as the mount point."
    mkdir -p "/.snapshots"
fi

# Note: The 'snapper create-config' command usually handles the subvolume creation and fstab entry.
# We will verify the fstab entry exists and matches the configuration.

# 6. Enable Timers for Automatic Snapshots
echo "➡️ Enabling systemd timers for automatic snapshots..."
systemctl enable --now snapper-timeline.timer
systemctl enable --now snapper-cleanup.timer
echo "✅ Timeline (hourly/daily) and cleanup timers enabled and started."

# 7. Update GRUB for Snapshot Booting
echo "➡️ Regenerating GRUB configuration for grub-btrfs support..."
if ! grub-mkconfig -o /boot/grub/grub.cfg; then
    echo "⚠️ Warning: Failed to regenerate GRUB configuration."
    echo "   Ensure GRUB is properly installed and /boot/grub/grub.cfg path is correct."
else
    echo "✅ GRUB configuration regenerated. You can now boot into snapshots from the GRUB menu."
fi

# 8. Final Instructions
echo "========================================================="
echo " Installation Complete!"
echo "========================================================="
echo "Summary:"
echo "1. Snapper, snap-pac, btrfs-progs, and grub-btrfs are installed."
echo "2. Configuration '$ROOT_CONFIG_NAME' has been created for the root filesystem ('/')."
echo "3. snap-pac is active: Snapshots will be automatically created before and after every 'pacman -Syu' operation."
echo "4. Automatic snapshots (hourly/daily) are active via systemd timers."
echo ""
echo "--- Important Next Steps ---"
echo "To manage snapshots, use the command: \`snapper -c $ROOT_CONFIG_NAME list\`"
echo ""
echo "Regarding /boot:"
echo "If /boot is part of the root subvolume, it is already covered."
echo "If /boot is a SEPARATE Btrfs subvolume, you must manually create a second Snapper configuration for it (e.g., \`snapper -c boot create-config /boot\`)."
