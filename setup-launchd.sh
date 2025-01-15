#!/bin/bash

# Set up logging
LOG_DIR="$HOME/Projects/backup-scripts/logs"
LOG_FILE="$LOG_DIR/setup_launchd.log"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log messages
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to setup a launch agent
setup_launch_agent() {
    local plist_name="$1"
    local plist_source="$(pwd)/$plist_name"
    local plist_dest="$HOME/Library/LaunchAgents/$plist_name"
    
    log_message "Setting up $plist_name"
    
    # Create LaunchAgents directory if it doesn't exist
    if [ ! -d "$HOME/Library/LaunchAgents" ]; then
        log_message "Creating LaunchAgents directory"
        mkdir -p "$HOME/Library/LaunchAgents"
    fi
    
    # Remove existing symlink or file if it exists
    if [ -L "$plist_dest" ] || [ -f "$plist_dest" ]; then
        log_message "Removing existing plist file or symlink for $plist_name"
        # Unload the launch agent if it exists
        launchctl unload "$plist_dest" 2>/dev/null
        rm "$plist_dest"
    fi
    
    # Create the symbolic link
    log_message "Creating symbolic link for $plist_name"
    if ln -s "$plist_source" "$plist_dest"; then
        log_message "Successfully created symbolic link for $plist_name"
        # Load the launch agent
        if launchctl load "$plist_dest"; then
            log_message "Successfully loaded launch agent $plist_name"
            echo "Launch agent $plist_name has been set up and loaded successfully!"
        else
            log_message "ERROR: Failed to load launch agent $plist_name"
            echo "Failed to load launch agent $plist_name. Check the logs at $LOG_FILE"
            return 1
        fi
    else
        log_message "ERROR: Failed to create symbolic link for $plist_name"
        echo "Failed to create symbolic link for $plist_name. Check the logs at $LOG_FILE"
        return 1
    fi
}

# Setup both launch agents
setup_launch_agent "com.dlukianenko.backup-obsidian.plist"
setup_launch_agent "com.dlukianenko.backup-personal-docs.plist"
