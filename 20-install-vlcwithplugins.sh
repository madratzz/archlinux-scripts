#!/bin/bash

# Define the packages to install
VLC_PACKAGES=(
    vlc                  # The core VLC package
    vlc-plugin-ffmpeg    # Crucial for many codecs (including H.264/H.265 decoding)
    vlc-plugin-matroska  # For MKV (Matroska) container support
    vlc-plugin-smb       # For Samba/SMB network share support
    vlc-plugin-nfs       # For NFS network share support
    vlc-plugin-x264      # For H.264/AVC encoding support (optional for playback)
    vlc-plugin-x265      # For H.265/HEVC encoding support (optional for playback)
)

# Note on MP4/H.264/H.265 playback:
# The core 'vlc' package handles MP4 container playback.
# 'vlc-plugin-ffmpeg' is what typically provides the necessary decoding support for
# H.264 and H.265 content, which are commonly found in MP4 and MKV files.

# Check if the user is root
#if [[ $EUID -ne 0 ]]; then
#   echo "This script must be run as root (use sudo)."
#   exit 1
#fi

echo "--- Installing VLC and specified plugins on Arch Linux ---"

# Use pacman to install the required packages
sudo pacman -S --noconfirm "${VLC_PACKAGES[@]}"

# Check the exit status of pacman
if [ $? -eq 0 ]; then
    echo "--- Installation complete! ---"
    echo "VLC and the following plugins were successfully installed:"
    printf "  - %s\n" "${VLC_PACKAGES[@]}"
else
    echo "--- Installation failed. Please check the pacman output for errors. ---"
fi

# Optional: Suggest the 'all' plugins package
echo ""
echo "💡 Alternatively, you could install all optional plugins with:"
echo "sudo pacman -S vlc-plugins-all"
