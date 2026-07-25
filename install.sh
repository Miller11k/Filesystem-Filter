#!/bin/sh

# Default mode if no flag is provided
MODE="${1:---user}"

# Set variables for building script's url (modular so it can be changed)
GITHUB_URL_BASE="https://raw.githubusercontent.com"
SCRIPT_FILE="filesystem_filter.sh"
REPO_NAME="Filesystem-Filter"
BRANCH="main"
GITHUB_USERNAME="Miller11k"

GITHUB_URL="$GITHUB_URL_BASE/$GITHUB_USERNAME/$REPO_NAME/$BRANCH/$SCRIPT_FILE"

# Store the script content in a variable (-s suppresses progress text)
SCRIPT_CODE=$(curl -fsSL "$GITHUB_URL") || {
    echo "Error: Failed to download script from $GITHUB_URL" >&2
    exit 1
}

# Install the script into the system
case "$MODE" in
  --user)
    echo "Installation set to user mode."

    BINARY_DIR="$HOME/.local/bin"                   # Define user binary directory
    TARGET_PATH="$BINARY_DIR/filesystem_filter"     # Define target path for the script executable
    SYMLINK_PATH="$BINARY_DIR/fsfltr"               # Define symbolic link path for fsfltr support

    mkdir -p "$BINARY_DIR"
    printf '%s\n' "$SCRIPT_CODE" > "$TARGET_PATH"   # Write code to path
    chmod +x "$TARGET_PATH"

    # Create a symlink named 'fsfltr' inside ~/.local/bin
    ln -sf "$TARGET_PATH" "$SYMLINK_PATH"

    # Check if target directory is in user's PATH and warn if missing
    case ":$PATH:" in
      *":$BINARY_DIR:"*) ;; # Already in PATH
      *)
        echo ""
        echo "Warning: $BINARY_DIR is not in your system PATH."
        echo "Add this line to your ~/.bashrc or ~/.zshrc to run commands from anywhere:"
        echo "  export PATH=\"\$PATH:$BINARY_DIR\""
        ;;
    esac

    # Inform user that user mode installation completed successfully
    echo "User installation/update successfully completed."
    echo "Commands available: 'filesystem_filter' or 'fsfltr'"
    ;;

  --system)
    echo "Installation set to system mode."

    # Verify the script is running with elevated root privileges (e.g., id -u = 0)
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: System mode requires root privileges." >&2
        echo "Please re-run using sudo." >&2
        exit 1  # Error if not sudo user
    fi

    BINARY_DIR="/usr/local/bin"                     # Define user binary directory
    TARGET_PATH="$BINARY_DIR/filesystem_filter"     # Define target path for the script executable
    SYMLINK_PATH="$BINARY_DIR/fsfltr"               # Define symbolic link path for fsfltr support

    mkdir -p "$BINARY_DIR"
    printf '%s\n' "$SCRIPT_CODE" > "$TARGET_PATH"   # Write code to path

    # Set proper file permissions and ownership (chmod +x, root:root)
    chmod 755 "$TARGET_PATH"
    chown root:root "$TARGET_PATH"

    # Create a system-wide symlink named 'fsfltr'
    ln -sf "$TARGET_PATH" "$SYMLINK_PATH"

    # Inform user that system mode installation completed successfully
    echo "System installation/update successfully completed."
    echo "Commands available: 'filesystem_filter' or 'fsfltr'"
    ;;
esac