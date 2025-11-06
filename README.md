# Backup Scripts

A robust collection of shell scripts for automated Git-based backups with enhanced reliability, notifications, and monitoring.

## Features

- **Modular Design**: Shared library for common backup functions
- **Multiple Backup Jobs**: Configure unlimited backup jobs in one place
- **Smart Notifications**: macOS notifications, email, and webhook support (Slack, Discord)
- **Retry Logic**: Automatic retries with exponential backoff for network failures
- **Log Rotation**: Automatic log rotation (keeps last 10 logs, max 10MB each)
- **Backup Verification**: Verifies commits were successfully pushed to remote
- **Health Check**: Script to monitor backup job status and health
- **Dry Run Mode**: Test backups without making actual changes
- **Conflict Detection**: Better handling of merge conflicts

## Quick Start

1. Clone this repository
2. Copy `config.template.sh` to `config.sh`:
   ```bash
   cp config.template.sh config.sh
   ```
3. Edit `config.sh` with your paths and preferences
4. Run a backup:
   ```bash
   ./backup-to-git.sh obsidian
   ```

## Configuration

### Backup Jobs

Define your backup jobs in `config.sh` using the `BACKUP_JOBS` associative array:

```bash
declare -A BACKUP_JOBS
BACKUP_JOBS[obsidian]="$HOME/Documents/ObsidianVault"
BACKUP_JOBS[personal-docs]="$HOME/Documents/Personal"
BACKUP_JOBS[my-project]="$HOME/Projects/MyProject"
```

### Notification Settings

Enable notifications in `config.sh`:

```bash
# macOS Notifications
ENABLE_MACOS_NOTIFICATIONS=true

# Email Notifications
ENABLE_EMAIL_NOTIFICATIONS=true
NOTIFICATION_EMAIL="you@example.com"

# Webhook Notifications (Slack, Discord, etc.)
ENABLE_WEBHOOK_NOTIFICATIONS=true
WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### Backup Options

```bash
# Verify backups were pushed successfully
VERIFY_BACKUP=true

# Test mode - don't make actual changes
DRY_RUN=false
```

## Scripts

### Core Scripts

- **`backup-to-git.sh <job_name> [branch]`**: Generic backup script for any job
  ```bash
  ./backup-to-git.sh obsidian          # Backup to main branch
  ./backup-to-git.sh my-project dev    # Backup to dev branch
  ```

- **`health-check.sh`**: Check health of all backup jobs
  ```bash
  ./health-check.sh
  ```

### Legacy Scripts (now using shared library)

- **`backup-obsidian.sh`**: Backs up Obsidian vault
- **`backup-personal-docs.sh`**: Backs up personal documents

## Automated Backups (macOS)

Set up automated backups using launchd:

1. Copy and edit the setup script:
   ```bash
   cp setup-launchd.template.sh setup-launchd.sh
   chmod +x setup-launchd.sh
   ```

2. Run the setup script:
   ```bash
   ./setup-launchd.sh
   ```

The backups will run:
- Daily at midnight
- On system boot
- Immediately after setup

## Health Monitoring

Run the health check to verify all backups are working:

```bash
./health-check.sh
```

This checks:
- Directory existence
- Git repository status
- Remote configuration
- Uncommitted changes
- Sync status with remote
- Last commit time
- Log files and errors
- Launch agent status (macOS)

## Logs

Logs are stored in the `logs` directory with automatic rotation:
- Maximum 10 rotated logs per job
- Maximum 10MB per log file
- Logs are excluded from Git

View logs:
```bash
tail -f logs/obsidian_backup.log
```

## Advanced Features

### Dry Run Mode

Test backups without making changes:

```bash
DRY_RUN=true ./backup-to-git.sh obsidian
```

### Custom Branch

Backup to a specific branch:

```bash
./backup-to-git.sh my-project feature-branch
```

### Retry Logic

Git operations automatically retry up to 4 times with exponential backoff (2s, 4s, 8s, 16s) on network failures.

### Backup Verification

After pushing, the script verifies that local and remote are in sync. Disable with:

```bash
VERIFY_BACKUP=false
```

## Troubleshooting

1. **Check backup health**:
   ```bash
   ./health-check.sh
   ```

2. **View logs**:
   ```bash
   cat logs/obsidian_backup.log
   ```

3. **Test in dry run mode**:
   ```bash
   DRY_RUN=true ./backup-to-git.sh obsidian
   ```

4. **Check launch agent status (macOS)**:
   ```bash
   launchctl list | grep backup
   ```

## Architecture

```
backup-scripts/
├── lib/
│   └── backup-functions.sh    # Shared library with all core functions
├── logs/                       # Auto-rotated log files
├── backup-to-git.sh           # Generic backup script
├── backup-obsidian.sh         # Legacy Obsidian backup
├── backup-personal-docs.sh    # Legacy personal docs backup
├── health-check.sh            # Health monitoring script
├── setup-launchd.sh           # macOS automation setup
└── config.sh                  # Your configuration
```

## Requirements

- Git
- Bash 4.0+ (for associative arrays)
- macOS (for launchd automation and notifications)
- Optional: `mail` command for email notifications
- Optional: `curl` for webhook notifications
