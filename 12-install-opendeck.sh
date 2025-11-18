#!/bin/bash
#
# This script executes the OpenDeck installation script found on the
# nekename/OpenDeck GitHub repository by fetching it via curl and
# piping it directly into a bash shell.

#echo "--- Fetching and running the OpenDeck installation script ---"
#echo "Source: https://raw.githubusercontent.com/nekename/OpenDeck/main/install_opendeck.sh"
#echo ""

# Execute the remote script
#bash <(curl -sSL https://raw.githubusercontent.com/nekename/OpenDeck/main/install_opendeck.sh)

echo "--- Fetching and running the OpenDeck installation script ---"
echo ""
yay -S opendeck --noconfirm



if [ $? -eq 0 ]; then
    echo ""
    echo "✅ OpenDeck script execution finished successfully."
else
    echo ""
    echo "❌ OpenDeck script execution returned an error."
fi
