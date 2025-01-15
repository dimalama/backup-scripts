#!/bin/bash

# Source configuration
CONFIG_FILE="$(dirname "$0")/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.sh not found. Please copy config.template.sh to config.sh and configure it."
    exit 1
fi
source "$CONFIG_FILE"

# Set up logging
LOG_DIR="$BACKUP_SCRIPTS_DIR/logs"
LOG_FILE="$LOG_DIR/personal_docs_backup.log"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log messages
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Check if docs directory exists
if [ ! -d "$PERSONAL_DOCS_DIR" ]; then
    log_message "ERROR: Personal docs directory does not exist: $PERSONAL_DOCS_DIR"
    exit 1
fi

# Navigate to the folder you want to back up
if ! cd "$PERSONAL_DOCS_DIR"; then
    log_message "ERROR: Failed to change directory - Make sure the drive is mounted"
    exit 1
fi

# Pull latest changes first
log_message "Pulling latest changes"
if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    if ! git pull origin main >> "$LOG_FILE" 2>&1; then
        log_message "WARNING: Pull failed, there might be conflicts"
    fi
else
    log_message "No upstream branch configured, skipping pull"
fi

# Add all changes to Git
log_message "Starting backup process"

# Ensure git knows who we are
if [ -z "$(git config --get user.email)" ] && [ -n "$GIT_USER_EMAIL" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
    git config --global user.name "$GIT_USER_NAME"
fi

git add . >> "$LOG_FILE" 2>&1

# Check if we have any changes to commit
if git diff-index --quiet HEAD --; then
    log_message "No changes to commit"
    CHANGES_MADE=false
else
    # We have changes, commit them
    if git commit -m "Automated backup on $(date +'%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1; then
        log_message "Changes committed successfully"
        CHANGES_MADE=true
    else
        log_message "ERROR: Failed to commit changes"
        exit 1
    fi
fi

# Push changes if we have any
log_message "Pushing commits to remote"
if git push origin main >> "$LOG_FILE" 2>&1; then
    log_message "Backup completed successfully"
else
    log_message "WARNING: Failed to push changes - will retry on next run"
    # Don't exit with error, just continue
fi

exit 0
