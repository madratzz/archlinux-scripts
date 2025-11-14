#!/bin/sh

sudo mkdir /mnt/work
sudo mkdir /mnt/games

sudo chown 1000:1000 /mnt/work
sudo chown 1000:1000 /mnt/games


FSTAB_FILE="/etc/fstab"

# --- Drive 1: /mnt/work (sda1) ---
UUID_WORK="3e812875-3c50-46c2-a129-d23dc6a7cd28"
COMMENT_WORK="# /dev/sda1 mounted to /mnt/work (using UUID)"
LINE_WORK="UUID=${UUID_WORK} /mnt/work ext4 defaults,noatime 0 2"

# --- Drive 2: /mnt/games (nvme1n1p1) ---
UUID_GAMES="d4aa9a76-ce53-4a5e-ab81-6f1303a1b710"
COMMENT_GAMES="# /dev/nvme1n1p1 mounted to /mnt/games (using UUID)"
LINE_GAMES="UUID=${UUID_GAMES} /mnt/games ext4 defaults,noatime 0 2"

echo "--- Checking fstab entries ---"

# ------------------------------------
# 1. CHECK AND ADD /mnt/work (sda1)
# ------------------------------------
if ! grep -q "${UUID_WORK}" "${FSTAB_FILE}"; then
    echo "Adding /mnt/work entry..."
    # Add a blank line and comment, then the main entry
    {
        echo ""
        echo "${COMMENT_WORK}"
        echo "${LINE_WORK}"
    } | sudo tee -a "${FSTAB_FILE}"
else
    echo "/mnt/work entry (UUID: ${UUID_WORK}) already exists. Skipping."
fi

# ------------------------------------
# 2. CHECK AND ADD /mnt/games (nvme1n1p1)
# ------------------------------------
if ! grep -q "${UUID_GAMES}" "${FSTAB_FILE}"; then
    echo "Adding /mnt/games entry..."
    # Add a blank line and comment, then the main entry
    {
        echo ""
        echo "${COMMENT_GAMES}"
        echo "${LINE_GAMES}"
    } | sudo tee -a "${FSTAB_FILE}"
else
    echo "/mnt/games entry (UUID: ${UUID_GAMES}) already exists. Skipping."
fi

echo "--- fstab configuration complete ---"


# Append comment line
#echo "# /dev/sda1 mounted to /mnt/work (using UUID)" | sudo tee -a /etc/fstab

# Append fstab entry
#echo "UUID=3e812875-3c50-46c2-a129-d23dc6a7cd28 /mnt/work ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab

# Append comment line
#echo "" | sudo tee -a /etc/fstab # Add a blank line for readability
#echo "# /dev/nvme1n1p1 mounted to /mnt/games (using UUID)" | sudo tee -a /etc/fstab

# Append fstab entry
#echo "UUID=d4aa9a76-ce53-4a5e-ab81-6f1303a1b710 /mnt/games ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab

sudo systemctl daemon-reload

sudo mount -a 
