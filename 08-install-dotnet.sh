#!/bin/bash
#
# C#/.NET Development Setup Script for Arch Linux
# Installs the official 'dotnet-sdk' package.

# Define the package name
DOTNET_PACKAGE="dotnet-sdk"

echo "--- Starting .NET SDK Installation for Arch Linux ---"
echo ""

# Check for package manager (sanity check for Arch)
if ! command -v pacman &> /dev/null; then
    echo "❌ Error: 'pacman' command not found. This script is intended for Arch Linux."
    exit 1
fi

# Check for root permissions
if [[ $EUID -ne 0 ]]; then
    echo "⚠️ This script requires root privileges to install packages."
    echo "Running command with 'sudo'..."
    SUDO="sudo"
else
    SUDO=""
fi

# 1. Update system packages
echo "Updating system packages (pacman -Syu --noconfirm)..."
$SUDO pacman -Syu --noconfirm

# Check if the update was successful
if [ $? -ne 0 ]; then
    echo "❌ System update failed. Please resolve the issue and run the script again."
    exit 1
fi

echo "✅ System packages updated."
echo ""

# 2. Install the .NET SDK
echo "Installing the .NET SDK: $DOTNET_PACKAGE (pacman -S --noconfirm $DOTNET_PACKAGE)..."
$SUDO pacman -S --noconfirm "$DOTNET_PACKAGE"

# Check if the installation was successful
if [ $? -ne 0 ]; then
    echo "❌ Installation of $DOTNET_PACKAGE failed. Exiting."
    exit 1
fi

echo "✅ $DOTNET_PACKAGE installed successfully."
echo ""

# 3. Verification and Final Information
echo "--- Verifying .NET Environment ---"

if command -v dotnet &> /dev/null; then
    echo "✅ 'dotnet' command found."
    echo "Current .NET SDK Version:"
    dotnet --version
    echo ""
    echo "Installed Runtimes and SDKs:"
    dotnet --list-sdks
    dotnet --list-runtimes
    echo ""

    # Verify MSBuild (it is part of the SDK, but a specific check is useful)
    MSBUILD_PATH=$(find /usr/share/dotnet/sdk/ -name "MSBuild.dll" -print -quit 2>/dev/null)
    if [ -n "$MSBUILD_PATH" ]; then
        echo "✅ MSBuild component found within the SDK."
        echo "You can now create and build projects using the 'dotnet' CLI."
    else
        echo "⚠️ MSBuild component path not immediately found. It should still be functional via 'dotnet build'."
    fi

    echo ""
    echo "--- Installation Complete! ---"
    echo "You can start a new project with: dotnet new console -o MyNewApp"
else
    echo "❌ Verification failed: 'dotnet' command not found after installation."
    echo "Please try restarting your terminal or manually installing the package."
fi
