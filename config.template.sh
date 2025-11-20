#!/usr/local/bin/bash

# ============================================
# Backup Scripts Configuration
# ============================================

# Path to this backup scripts directory
export BACKUP_SCRIPTS_DIR="$HOME/path/to/backup-scripts"

# ============================================
# Backup Jobs Configuration
# ============================================
# Define your backup jobs as an associative array
# Format: BACKUP_JOBS[job_name]="path/to/directory"

declare -A BACKUP_JOBS
BACKUP_JOBS[obsidian]="$HOME/path/to/obsidian/vault"
BACKUP_JOBS[personal-docs]="/path/to/personal/documents"
# Add more backup jobs as needed:
# BACKUP_JOBS[my-project]="$HOME/path/to/my-project"
# BACKUP_JOBS[photos]="/Volumes/External/Photos"

# Legacy variables (for backward compatibility with old scripts)
export OBSIDIAN_DIR="${BACKUP_JOBS[obsidian]}"
export PERSONAL_DOCS_DIR="${BACKUP_JOBS[personal-docs]}"

# ============================================
# Git Configuration
# ============================================
export GIT_USER_EMAIL="your-email@example.com"
export GIT_USER_NAME="Your Name"

# ============================================
# Backup Options
# ============================================
# Verify that backups were pushed successfully
export VERIFY_BACKUP=true

# Dry run mode (test without making changes)
export DRY_RUN="${DRY_RUN:-false}"

# ============================================
# Notification Settings
# ============================================

# macOS Notifications
export ENABLE_MACOS_NOTIFICATIONS=true

# Email Notifications
export ENABLE_EMAIL_NOTIFICATIONS=false
export NOTIFICATION_EMAIL="your-email@example.com"

# Webhook Notifications (Slack, Discord, etc.)
export ENABLE_WEBHOOK_NOTIFICATIONS=false
export WEBHOOK_URL=""
# Examples:
# Slack: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
# Discord: https://discord.com/api/webhooks/YOUR/WEBHOOK/URL
