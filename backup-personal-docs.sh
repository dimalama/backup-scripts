#!/usr/local/bin/bash

# Personal Documents Backup Script
# This script backs up your personal documents to Git
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
init_logging "personal_docs_backup.log"

# Start backup
log_message "================================================" "INFO"
log_message "Starting personal documents backup" "INFO"
log_message "Directory: $PERSONAL_DOCS_DIR" "INFO"
log_message "================================================" "INFO"

# Perform the backup
if perform_backup "$PERSONAL_DOCS_DIR" "Personal Documents" "main"; then
    log_message "Personal documents backup completed successfully" "SUCCESS"
    exit 0
else
    log_message "Personal documents backup failed" "ERROR"
    exit 1
fi
