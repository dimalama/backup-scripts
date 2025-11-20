#!/usr/local/bin/bash

# Source configuration
CONFIG_FILE="$(dirname "$0")/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.sh not found. Please copy config.template.sh to config.sh and configure it."
    exit 1
fi
source "$CONFIG_FILE"

# Function to setup a launch agent
setup_launch_agent() {
    local template_file="$1"
    local target_name="${template_file%.template.plist}"
    local target_file="$HOME/Library/LaunchAgents/${target_name##*/}"
    
    # Create target directory if it doesn't exist
    mkdir -p "$HOME/Library/LaunchAgents"
    
    # Copy template and replace placeholders
    sed -e "s|/path/to/backup-scripts|$BACKUP_SCRIPTS_DIR|g" \
        "$template_file" > "$target_file"
    
    # Set correct permissions
    chmod 644 "$target_file"
    
    # Load the launch agent
    launchctl unload "$target_file" 2>/dev/null || true
    if launchctl load "$target_file"; then
        echo "Successfully loaded $target_file"
    else
        echo "Failed to load $target_file"
        exit 1
    fi
}

# Setup both launch agents
setup_launch_agent "com.example.backup-obsidian.template.plist"
setup_launch_agent "com.example.backup-personal-docs.template.plist"
