#!/bin/bash

# --- Configuration ---
FISH_SHELL_PATH="/usr/bin/fish"
FISH_CONFIG_DIR="$HOME/.config/fish"
FISH_CONFIG_FILE="$FISH_CONFIG_DIR/config.fish"

# --- Functions ---

# Function to check for and refresh sudo credentials
check_and_refresh_sudo() {
    # If the user is root, proceed, as chsh requires sudo access for non-root users.
    if [[ $(id -u) -eq 0 ]]; then
        echo "✅ Running as root. Proceeding."
        return 0
    fi

    echo "🚨 This script requires elevated privileges (sudo) to change your default shell."

    if sudo -v; then
        echo "✅ Sudo credentials successfully validated. Proceeding."
        return 0
    else
        echo "❌ Sudo access denied or command failed. Exiting."
        exit 1
    fi
}

# --- Main Script Execution ---

echo "🚀 Starting Fish Shell configuration and setup."
echo "--------------------------------------------------------"

# 1. Validate sudo credentials (needed for chsh)
check_and_refresh_sudo

# 2. Check if Fish is installed
if ! command -v fish &> /dev/null; then
    echo "❌ ERROR: Fish shell not found at $FISH_SHELL_PATH."
    echo "Please ensure 'fish' is installed before running this script (using install_cli_tools.sh)."
    exit 1
fi

# 3. Change the default shell using chsh
echo "🐚 Changing default shell to Fish ($FISH_SHELL_PATH)..."
if sudo chsh -s "$FISH_SHELL_PATH" "$USER"; then
    echo "✅ Default shell successfully changed for user $USER."
else
    echo "❌ Failed to change default shell. Check permissions."
    exit 1
fi

# 4. Create the Fish configuration directory
echo "📁 Ensuring Fish config directory exists: $FISH_CONFIG_DIR"
if mkdir -p "$FISH_CONFIG_DIR"; then
    echo "✅ Directory created/verified."
else
    echo "❌ Failed to create config directory. Check permissions."
    exit 1
fi

# 5. Append the aliases to config.fish
echo "📝 Appending aliases to $FISH_CONFIG_FILE..."
# We use '>>' instead of '>' to append the new content, preserving any existing configuration.
cat << EOL >> "$FISH_CONFIG_FILE"

# ==========================================================
# Fish Configuration for Modern CLI Tools (Appended Block)
# Created by setup_fish_shell.sh
# ==========================================================

# --- Aliases for Enhanced Tools ---

# eza (Replaces 'ls' with modern, colored listing)
# -a: show all files
# -l: long format
# --group-directories-first: lists directories before files
alias ls 'eza -al --group-directories-first'

# bat (Replaces 'cat' with syntax highlighting and Git integration)
alias cat 'bat --paging=never'
alias less 'bat'

# fd (Replaces 'find' with faster, simpler syntax)
alias find 'fd'

# duf (Replaces 'df' with a better-looking disk usage visualization)
alias df 'duf'

# dust (Replaces 'du' with a visual representation of disk usage)
alias du 'dust'

# ripgrep (Replaces 'grep' with faster, recursive searching)
alias grep 'rg'

# zoxide (Jump to frequently used directories)
# Note: zoxide typically hooks itself automatically, but we add an alias for flexibility
alias cd 'z'

# broot (Interactive tree view with fuzzy search)
alias br 'broot'

# btop (Interactive, colorful resource monitor)
alias top 'btop'

# tldr (Simplified, community-driven man pages)
alias help 'tldr'

# --- End of Aliases ---

# --- Other Configurations ---

# Set up zoxide shell integration (required for z command to work)
zoxide init fish | source
EOL

echo "✅ Aliases and zoxide integration appended to $FISH_CONFIG_FILE."
echo "--------------------------------------------------------"
echo "🎉 Setup Complete!"
echo "To use Fish as your interactive shell, please **log out and log back in**."
echo "You will then have access to the new aliases (e.g., 'ls' runs 'eza', 'top' runs 'btop')."
