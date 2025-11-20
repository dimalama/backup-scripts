#!/usr/local/bin/bash

# Shared library for backup scripts
# This file contains common functions used across all backup scripts

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize logging for a backup job
# Usage: init_logging <log_file_name>
init_logging() {
    local log_file_name="$1"
    LOG_DIR="${BACKUP_SCRIPTS_DIR}/logs"
    LOG_FILE="${LOG_DIR}/${log_file_name}"

    # Create logs directory if it doesn't exist
    mkdir -p "$LOG_DIR"

    # Rotate logs if needed (keep last 10 logs, each max 10MB)
    rotate_logs "$LOG_FILE"
}

# Rotate log files
# Usage: rotate_logs <log_file_path>
rotate_logs() {
    local log_file="$1"
    local max_size=$((10 * 1024 * 1024)) # 10MB
    local max_rotations=10

    if [ -f "$log_file" ]; then
        local size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
        if [ "$size" -gt "$max_size" ]; then
            # Rotate logs
            for i in $(seq $((max_rotations - 1)) -1 1); do
                if [ -f "${log_file}.${i}" ]; then
                    mv "${log_file}.${i}" "${log_file}.$((i + 1))"
                fi
            done
            mv "$log_file" "${log_file}.1"
        fi
    fi
}

# Log message to file and optionally to console
# Usage: log_message "message" [level]
log_message() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
    local log_entry="$timestamp - [$level] - $message"

    echo "$log_entry" >> "$LOG_FILE"

    # Also output to console if not running from launchd
    if [ -t 1 ]; then
        case "$level" in
            ERROR)
                echo -e "${RED}${log_entry}${NC}"
                ;;
            WARNING)
                echo -e "${YELLOW}${log_entry}${NC}"
                ;;
            SUCCESS)
                echo -e "${GREEN}${log_entry}${NC}"
                ;;
            *)
                echo "$log_entry"
                ;;
        esac
    fi
}

# Send notification
# Usage: send_notification "title" "message" "level"
send_notification() {
    local title="$1"
    local message="$2"
    local level="${3:-INFO}"

    # macOS notification
    if command -v osascript >/dev/null 2>&1 && [ "${ENABLE_MACOS_NOTIFICATIONS:-false}" = "true" ]; then
        osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
    fi

    # Email notification
    if [ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" = "true" ] && [ -n "$NOTIFICATION_EMAIL" ]; then
        send_email_notification "$title" "$message" "$level"
    fi

    # Webhook notification (Slack, Discord, etc.)
    if [ "${ENABLE_WEBHOOK_NOTIFICATIONS:-false}" = "true" ] && [ -n "$WEBHOOK_URL" ]; then
        send_webhook_notification "$title" "$message" "$level"
    fi
}

# Send email notification
send_email_notification() {
    local title="$1"
    local message="$2"
    local level="$3"

    if command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "[$level] $title" "$NOTIFICATION_EMAIL" 2>/dev/null || {
            log_message "Failed to send email notification" "WARNING"
        }
    fi
}

# Send webhook notification
send_webhook_notification() {
    local title="$1"
    local message="$2"
    local level="$3"

    if command -v curl >/dev/null 2>&1; then
        local payload
        if [[ "$WEBHOOK_URL" == *"slack.com"* ]]; then
            # Slack format
            payload="{\"text\":\"[$level] $title\",\"attachments\":[{\"text\":\"$message\"}]}"
        elif [[ "$WEBHOOK_URL" == *"discord.com"* ]]; then
            # Discord format
            payload="{\"content\":\"**[$level] $title**\\n$message\"}"
        else
            # Generic JSON format
            payload="{\"title\":\"$title\",\"message\":\"$message\",\"level\":\"$level\"}"
        fi

        curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$payload" >/dev/null 2>&1 || {
            log_message "Failed to send webhook notification" "WARNING"
        }
    fi
}

# Execute git command with retry logic
# Usage: git_with_retry <max_attempts> <delay> <git_command> [args...]
git_with_retry() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        else
            local exit_code=$?
            if [ $attempt -lt $max_attempts ]; then
                log_message "Git command failed (attempt $attempt/$max_attempts), retrying in ${delay}s..." "WARNING"
                sleep "$delay"
                delay=$((delay * 2)) # Exponential backoff
                attempt=$((attempt + 1))
            else
                log_message "Git command failed after $max_attempts attempts" "ERROR"
                return $exit_code
            fi
        fi
    done
}

# Setup git user if not configured
setup_git_user() {
    if [ -z "$(git config --get user.email)" ] && [ -n "$GIT_USER_EMAIL" ]; then
        git config user.email "$GIT_USER_EMAIL"
        git config user.name "$GIT_USER_NAME"
        log_message "Configured git user: $GIT_USER_NAME <$GIT_USER_EMAIL>"
    fi
}

# Ensure we're on the correct branch
# Usage: ensure_branch <branch_name>
ensure_branch() {
    local target_branch="$1"
    local current_branch

    # Get current branch name
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_message "Failed to determine current branch" "ERROR"
        return 1
    fi

    # Check if we're already on the target branch
    if [ "$current_branch" = "$target_branch" ]; then
        log_message "Already on branch '$target_branch'" "INFO"
        return 0
    fi

    log_message "Current branch is '$current_branch', need to switch to '$target_branch'" "INFO"

    # Check if there are uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        log_message "ERROR: Cannot switch branches - uncommitted changes detected" "ERROR"
        log_message "Please commit or stash changes on branch '$current_branch' before running backup" "ERROR"
        return 1
    fi

    # Check if the target branch exists locally
    if git show-ref --verify --quiet "refs/heads/$target_branch"; then
        # Branch exists locally, switch to it
        log_message "Switching to existing local branch '$target_branch'" "INFO"
        if git checkout "$target_branch" >> "$LOG_FILE" 2>&1; then
            log_message "Successfully switched to branch '$target_branch'" "SUCCESS"
            return 0
        else
            log_message "Failed to switch to branch '$target_branch'" "ERROR"
            return 1
        fi
    else
        # Branch doesn't exist locally, check if it exists on remote
        if git fetch origin "$target_branch" >> "$LOG_FILE" 2>&1; then
            log_message "Creating local branch '$target_branch' from origin/$target_branch" "INFO"
            if git checkout -b "$target_branch" "origin/$target_branch" >> "$LOG_FILE" 2>&1; then
                log_message "Successfully created and switched to branch '$target_branch'" "SUCCESS"
                return 0
            else
                log_message "Failed to create branch '$target_branch' from remote" "ERROR"
                return 1
            fi
        else
            log_message "ERROR: Branch '$target_branch' does not exist locally or on remote" "ERROR"
            return 1
        fi
    fi
}

# Pull latest changes from remote
# Usage: git_pull_latest
git_pull_latest() {
    local branch="${1:-main}"

    log_message "Pulling latest changes from origin/$branch"

    if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
        if git_with_retry 3 2 git pull origin "$branch" >> "$LOG_FILE" 2>&1; then
            log_message "Successfully pulled latest changes" "SUCCESS"
            return 0
        else
            log_message "Pull failed, there might be conflicts" "WARNING"
            return 1
        fi
    else
        log_message "No upstream branch configured, skipping pull"
        return 0
    fi
}

# Commit changes if there are any
# Usage: git_commit_changes "commit_message"
git_commit_changes() {
    local commit_message="$1"
    local git_timeout=300  # 5 minutes timeout for git operations

    log_message "Adding changes to git index..."

    # Use timeout to prevent hanging on iCloud-synced directories
    if ! timeout "$git_timeout" git add . >> "$LOG_FILE" 2>&1; then
        log_message "Git add operation timed out or failed (may be caused by iCloud sync conflicts)" "ERROR"
        # Try to clean up any stale lock files
        rm -f .git/index.lock 2>/dev/null
        return 2
    fi

    # Check if we have any changes to commit
    if git diff-index --quiet HEAD --; then
        log_message "No changes to commit"
        return 1
    else
        log_message "Committing changes..."
        if timeout "$git_timeout" git commit -m "$commit_message" >> "$LOG_FILE" 2>&1; then
            log_message "Changes committed successfully" "SUCCESS"
            return 0
        else
            log_message "Failed to commit changes" "ERROR"
            # Clean up lock file if commit failed
            rm -f .git/index.lock 2>/dev/null
            return 2
        fi
    fi
}

# Push changes to remote with retry
# Usage: git_push_changes [branch]
git_push_changes() {
    local branch="${1:-main}"

    log_message "Pushing commits to origin/$branch"

    if git_with_retry 4 2 git push origin "$branch" >> "$LOG_FILE" 2>&1; then
        log_message "Backup completed successfully" "SUCCESS"
        return 0
    else
        log_message "Failed to push changes after multiple attempts" "ERROR"
        return 1
    fi
}

# Verify that the backup was pushed successfully
# Usage: verify_backup_pushed [branch]
verify_backup_pushed() {
    local branch="${1:-main}"

    log_message "Verifying backup was pushed successfully"

    # Fetch the remote branch
    if ! git fetch origin "$branch" >> "$LOG_FILE" 2>&1; then
        log_message "Failed to fetch remote branch for verification" "WARNING"
        return 1
    fi

    # Check if local and remote are in sync
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse "origin/$branch")

    if [ "$local_commit" = "$remote_commit" ]; then
        log_message "Verification successful: local and remote are in sync" "SUCCESS"
        return 0
    else
        log_message "Verification failed: local and remote are not in sync" "ERROR"
        return 1
    fi
}

# Check for merge conflicts
# Usage: check_for_conflicts
check_for_conflicts() {
    if git ls-files -u | grep -q .; then
        log_message "Merge conflicts detected!" "ERROR"
        git status >> "$LOG_FILE" 2>&1
        return 1
    fi
    return 0
}

# Perform a complete backup
# Usage: perform_backup <backup_dir> <backup_name> [branch]
perform_backup() {
    local backup_dir="$1"
    local backup_name="$2"
    local branch="${3:-main}"
    local dry_run="${DRY_RUN:-false}"

    # Check if directory exists
    if [ ! -d "$backup_dir" ]; then
        log_message "ERROR: Backup directory does not exist: $backup_dir" "ERROR"
        send_notification "Backup Failed: $backup_name" "Directory not found: $backup_dir" "ERROR"
        return 1
    fi

    # Navigate to backup directory
    if ! cd "$backup_dir"; then
        log_message "ERROR: Failed to change directory to: $backup_dir" "ERROR"
        send_notification "Backup Failed: $backup_name" "Cannot access directory: $backup_dir" "ERROR"
        return 1
    fi

    # Check if it's a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_message "ERROR: Not a git repository: $backup_dir" "ERROR"
        send_notification "Backup Failed: $backup_name" "Not a git repository: $backup_dir" "ERROR"
        return 1
    fi

    # Clean up any stale git lock files before starting
    if [ -f ".git/index.lock" ]; then
        log_message "Removing stale git lock file" "WARNING"
        rm -f .git/index.lock 2>/dev/null || {
            log_message "Failed to remove stale lock file" "ERROR"
            send_notification "Backup Failed: $backup_name" "Unable to remove stale git lock file" "ERROR"
            return 1
        }
    fi

    # Setup git user
    setup_git_user

    # Ensure we're on the correct branch
    if ! ensure_branch "$branch"; then
        send_notification "Backup Failed: $backup_name" "Failed to switch to branch '$branch'" "ERROR"
        return 1
    fi

    # Pull latest changes
    if ! git_pull_latest "$branch"; then
        if ! check_for_conflicts; then
            send_notification "Backup Failed: $backup_name" "Merge conflicts detected" "ERROR"
            return 1
        fi
    fi

    if [ "$dry_run" = "true" ]; then
        log_message "DRY RUN: Would commit and push changes"
        git status >> "$LOG_FILE" 2>&1
        return 0
    fi

    # Commit changes
    local commit_result
    git_commit_changes "Automated backup on $(date +'%Y-%m-%d %H:%M:%S')"
    commit_result=$?

    if [ $commit_result -eq 2 ]; then
        # Commit failed
        send_notification "Backup Failed: $backup_name" "Failed to commit changes" "ERROR"
        return 1
    elif [ $commit_result -eq 1 ]; then
        # No changes to commit
        log_message "Backup completed: no changes detected"
        return 0
    fi

    # Push changes
    if ! git_push_changes "$branch"; then
        send_notification "Backup Failed: $backup_name" "Failed to push changes to remote" "ERROR"
        return 1
    fi

    # Verify backup
    if [ "${VERIFY_BACKUP:-true}" = "true" ]; then
        if ! verify_backup_pushed "$branch"; then
            send_notification "Backup Warning: $backup_name" "Verification failed: local and remote may not be in sync" "WARNING"
        fi
    fi

    send_notification "Backup Successful: $backup_name" "Backup completed successfully" "SUCCESS"
    return 0
}
