#!/bin/bash

# Obsidian Backup Script
# This script backs up your Obsidian vault to Git
# Now uses the shared library for improved reliability

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source configuration
CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.sh not found. Please copy config.template.sh to config.sh and configure it."
    exit 1
fi
source "$CONFIG_FILE"

# Source shared functions
LIB_FILE="$SCRIPT_DIR/lib/backup-functions.sh"
if [ ! -f "$LIB_FILE" ]; then
    echo "Error: lib/backup-functions.sh not found. Please ensure the library file exists."
    exit 1
fi
source "$LIB_FILE"

# Initialize logging
init_logging "obsidian_backup.log"

# Start backup
log_message "================================================" "INFO"
log_message "Starting Obsidian backup" "INFO"
log_message "Directory: $OBSIDIAN_DIR" "INFO"
log_message "================================================" "INFO"

# Perform the backup
if perform_backup "$OBSIDIAN_DIR" "Obsidian" "main"; then
    log_message "Obsidian backup completed successfully" "SUCCESS"
    exit 0
else
    log_message "Obsidian backup failed" "ERROR"
    exit 1
fi
