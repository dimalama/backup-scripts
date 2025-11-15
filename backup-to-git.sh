#!/bin/bash

# Generic Git Backup Script
# Usage: ./backup-to-git.sh <backup_name> [branch]
#
# backup_name: Name of the backup job defined in config.sh
# branch: Optional git branch (defaults to 'main')

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

# Parse arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup_name> [branch]"
    echo ""
    echo "Available backup jobs:"
    declare -p | grep "^declare -A BACKUP_JOBS" >/dev/null 2>&1 || {
        echo "  No backup jobs defined in config.sh"
        exit 1
    }
    for job_name in "${!BACKUP_JOBS[@]}"; do
        echo "  - $job_name"
    done
    exit 1
fi

BACKUP_NAME="$1"
BRANCH="${2:-main}"

# Get backup directory from config
if [ -z "${BACKUP_JOBS[$BACKUP_NAME]:-}" ]; then
    echo "Error: Backup job '$BACKUP_NAME' not found in config.sh"
    echo ""
    echo "Available backup jobs:"
    for job_name in "${!BACKUP_JOBS[@]}"; do
        echo "  - $job_name"
    done
    exit 1
fi

BACKUP_DIR="${BACKUP_JOBS[$BACKUP_NAME]}"

# Initialize logging
init_logging "${BACKUP_NAME}_backup.log"

# Start backup
log_message "================================================" "INFO"
log_message "Starting backup: $BACKUP_NAME" "INFO"
log_message "Directory: $BACKUP_DIR" "INFO"
log_message "Branch: $BRANCH" "INFO"
log_message "================================================" "INFO"

# Perform the backup
if perform_backup "$BACKUP_DIR" "$BACKUP_NAME" "$BRANCH"; then
    log_message "Backup completed successfully" "SUCCESS"
    exit 0
else
    log_message "Backup failed" "ERROR"
    exit 1
fi
