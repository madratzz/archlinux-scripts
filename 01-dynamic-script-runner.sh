#!/bin/bash
#
# Dynamically finds all executable .sh files in the current directory (excluding itself)
# and runs them sequentially in alphabetical order.

# --- Configuration ---
SCRIPT_EXTENSION=".sh"
MANAGER_SCRIPT_NAME=$(basename "$0") # Get the name of this script

echo "🚀 Starting Dynamic Script Manager"
echo "--------------------------------------------------------"
echo "Searching for executable *$SCRIPT_EXTENSION files in the current directory..."

# 1. Find target scripts
# Find all files ending in .sh, filter out this script, and ensure they are executable.
# The `ls -F` trick lists files with trailing slashes for directories, which we exclude.
# We then check executability and sort the results.
TARGET_SCRIPTS=()
for file in *${SCRIPT_EXTENSION}; do
    # Check if the file is a regular file, exists, and is executable
    if [ -f "$file" ] && [ -x "$file" ] && [ "$file" != "$MANAGER_SCRIPT_NAME" ]; then
        TARGET_SCRIPTS+=("$file")
    fi
done

# Sort the array alphabetically
IFS=$'\n' TARGET_SCRIPTS=($(sort <<<"${TARGET_SCRIPTS[*]}"))
unset IFS

if [ ${#TARGET_SCRIPTS[@]} -eq 0 ]; then
    echo "⚠️ No executable scripts found in the current directory to run (excluding $MANAGER_SCRIPT_NAME)."
    echo "Please ensure your scripts have executable permissions (e.g., chmod +x install_cli_tools.sh)."
    echo "--------------------------------------------------------"
    exit 0
fi

echo "Found the following scripts to execute:"
for script in "${TARGET_SCRIPTS[@]}"; do
    echo "  -> $script"
done
echo "--------------------------------------------------------"

# 2. Run scripts sequentially
SUCCESS_COUNT=0
FAILURE_COUNT=0

for script_name in "${TARGET_SCRIPTS[@]}"; do

    echo "⚙️ **RUNNING: $script_name**"

    # Execute the script using bash
    if bash "./$script_name"; then
        echo "✅ SUCCESS: $script_name finished."
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        EXIT_CODE=$?
        echo "❌ FAILURE: $script_name failed with exit code $EXIT_CODE."
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        echo "--- Continuing to the next script ---"
    fi
    echo "" # Newline for separation
done

# 3. Summary
echo "========================================================"
echo "✨ Script Execution Summary"
echo "========================================================"
echo "Total scripts found: $((SUCCESS_COUNT + FAILURE_COUNT))"
echo "Successful scripts: $SUCCESS_COUNT"
echo "Failed scripts: $FAILURE_COUNT"

if [ $FAILURE_COUNT -gt 0 ]; then
    echo "⚠️ One or more scripts failed. Review the output above for details."
else
    echo "🎉 All scripts executed successfully!"
fi
echo "========================================================"
