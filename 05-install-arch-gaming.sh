#!/bin/bash
#
# Arch Linux Gaming Setup Script for AMD (Radeon RX 7800 XT)
# Installs drivers, Gamescope, MangoHud, Wine, Lutris, Bottles, and Heroic Launcher.
# NOTE: Uses proton-ge-custom-bin for faster installation.

echo "--- Starting Arch Gaming Environment Setup ---"
echo ""

# --- 1. Check Permissions and AUR Helper ---
if [[ $EUID -ne 0 ]]; then
    echo "⚠️ Running script with 'sudo' for initial setup tasks."
    SUDO="sudo"
else
    SUDO=""
fi

# Function to install the AUR helper 'yay' if it is not found
install_yay() {
    if ! command -v yay &> /dev/null; then
        echo "🟡 'yay' (AUR Helper) not found. Installing dependencies and 'yay'..."
        $SUDO pacman -S --needed base-devel git --noconfirm

        # Check if base dependencies were installed successfully
        if [ $? -ne 0 ]; then
            echo "❌ Failed to install base development tools. Exiting."
            exit 1
        fi

        # Install yay
        git clone https://aur.archlinux.org/yay.git /tmp/yay-install
        (cd /tmp/yay-install && makepkg -si --noconfirm)
        if [ $? -ne 0 ]; then
            echo "❌ Failed to install 'yay' from AUR. Exiting."
            exit 1
        fi
        echo "✅ 'yay' installed successfully."
    else
        echo "✅ 'yay' is already installed."
    fi
}

install_yay

# Since yay is installed, we can remove the sudo command for package installation
# as yay runs makepkg/install as the current user.
SUDO=""

# --- 2. Define Package Lists ---

# Official Repositories (Drivers, Core Tools, Launchers)
PACMAN_PACKAGES=(
    # AMD DRIVERS & VULKAN (Essential for 7800 XT)
    mesa              # Core OpenGL driver
    vulkan-radeon     # AMD Vulkan driver
    lib32-mesa          # 32-bit OpenGL support
    lib32-vulkan-radeon # 32-bit Vulkan support for 32-bit games

    # GAMING TOOLS
    gamescope         # Micro-compositor for gaming
    mangohud          # In-game overlay
    wine-staging      # Latest Wine version (Staging branch is often best)
    winetricks        # Utility for Wine
    steam             # The main platform (if not already installed)

    # LAUNCHERS / WINE MANAGERS
    bottles
    lutris
)

# AUR Packages (GE Proton Binary, Heroic)
AUR_PACKAGES=(
    proton-ge-custom-bin      # The GloriousEggroll version of Proton (Binary)
    heroic-games-launcher-bin # Binary package for Heroic
)

ALL_PACKAGES=("${PACMAN_PACKAGES[@]}" "${AUR_PACKAGES[@]}")

# --- 3. Update and Install All Packages ---
echo ""
echo "Updating system and installing all gaming packages..."
echo "Packages to install: ${ALL_PACKAGES[@]}"
echo ""

# Use yay for combined installation and system update
# The '--answerclean' and '--answerdiff' flags ensure a non-interactive installation.
yay -Syu "${ALL_PACKAGES[@]}" --noconfirm --answerclean All --answerdiff None

if [ $? -ne 0 ]; then
    echo "❌ One or more package installations failed. Please review the output above."
    exit 1
fi

echo ""
echo "--- Installation Successful! ---"
echo ""

# --- 4. Post-Installation Notes ---
echo "✅ All packages installed successfully. Here are some important next steps for your 7800 XT setup:"
echo "--------------------------------------------------------------------------------------------------"

echo "🚀 **Vulkan/Drivers:** The necessary Mesa and Vulkan drivers (vulkan-radeon) for your 7800 XT are installed."
echo "   No proprietary AMD drivers are needed or recommended on Arch."

echo "🖥️ **Gamescope Setup:**"
echo "   Gamescope works best when run directly on a TTY or via your Display Manager (e.g., as a custom session)."
echo "   To test it, run a game with: \`gamescope -W 2560 -H 1440 -r 144 -- wine /path/to/game.exe\`"
echo "   (Adjust resolution and refresh rate as needed.)"

echo "📊 **MangoHud Usage:**"
echo "   You can prepend the command to any game launch: \`mangohud /path/to/game\`"
echo "   Or, configure it in Lutris/Bottles to run automatically."

echo "💾 **Proton-GE-Bin:**"
echo "   This is the faster-installing binary version. You will likely need to select 'Proton-GE' as the Wine/Proton version in Steam, Lutris, or Bottles."

echo "Enjoy your new Arch gaming machine!"
