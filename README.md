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
- **Branch Safety**: Automatic branch validation and switching to prevent data corruption

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

## macOS Setup Guide (Intel MacBook Pro)

### Prerequisites

Your Intel MacBook Pro should have the following installed:

```bash
# Check if git is installed
git --version
# Should show: git version 2.x.x or higher

# Check bash version
bash --version
# macOS comes with bash 3.2, which works fine for these scripts

# Check if you have curl (for webhooks, optional)
curl --version
```

If git is not installed, install it:
```bash
# Install via Homebrew (recommended)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install git

# Or install Xcode Command Line Tools
xcode-select --install
```

### Step-by-Step Setup

#### 1. Clone the Repository

```bash
# Clone to your home directory
cd ~
git clone <your-repo-url> backup-scripts
cd backup-scripts
```

#### 2. Prepare Your Git Repositories

Each directory you want to backup must be a git repository with a remote configured.

**Example: Setting up Obsidian vault backup**

```bash
# Navigate to your Obsidian vault
cd ~/Documents/ObsidianVault

# Initialize git if not already done
git init

# Create a .gitignore (optional, to exclude certain files)
cat > .gitignore << 'EOF'
.DS_Store
.obsidian/workspace*
.trash/
EOF

# Add remote repository (create this on GitHub/GitLab first)
git remote add origin https://github.com/yourusername/obsidian-vault.git

# Make initial commit
git add .
git commit -m "Initial commit"
git push -u origin main
```

Repeat this for each directory you want to backup (personal docs, projects, etc.).

#### 3. Configure the Backup Scripts

```bash
# Navigate to backup-scripts directory
cd ~/backup-scripts

# Copy the template configuration
cp config.template.sh config.sh

# Edit configuration with your favorite editor
nano config.sh
# or
vim config.sh
# or
open -e config.sh  # Opens in TextEdit
```

**Edit `config.sh` with your settings:**

```bash
#!/bin/bash

# Path to this backup scripts directory
export BACKUP_SCRIPTS_DIR="$HOME/backup-scripts"

# Define your backup jobs
declare -A BACKUP_JOBS
BACKUP_JOBS[obsidian]="$HOME/Documents/ObsidianVault"
BACKUP_JOBS[personal-docs]="$HOME/Documents/Personal"
# Add more as needed

# Git configuration
export GIT_USER_EMAIL="your-email@example.com"
export GIT_USER_NAME="Your Name"

# Enable macOS notifications
export ENABLE_MACOS_NOTIFICATIONS=true

# Optional: Email notifications (requires mail command)
export ENABLE_EMAIL_NOTIFICATIONS=false
export NOTIFICATION_EMAIL="your-email@example.com"

# Optional: Webhook notifications
export ENABLE_WEBHOOK_NOTIFICATIONS=false
export WEBHOOK_URL=""
```

#### 4. Test Your Backups

Before setting up automation, test each backup manually:

```bash
# Test in dry-run mode first (doesn't make changes)
DRY_RUN=true ./backup-to-git.sh obsidian

# If dry-run looks good, run actual backup
./backup-to-git.sh obsidian

# Check the logs
cat logs/obsidian_backup.log

# Run health check to verify everything is configured correctly
./health-check.sh
```

You should see output like:
```
================================================
Starting backup: obsidian
Directory: /Users/yourusername/Documents/ObsidianVault
Branch: main
================================================
Already on branch 'main'
Pulling latest changes from origin/main
Successfully pulled latest changes
Changes committed successfully
Backup completed successfully
```

#### 5. Set Up Automated Backups (Optional but Recommended)

**Using launchd for automatic backups:**

```bash
# Copy the setup script template
cp setup-launchd.template.sh setup-launchd.sh
chmod +x setup-launchd.sh

# Edit the template if needed (usually not necessary)
# Then run the setup
./setup-launchd.sh
```

This creates and loads launch agents that will:
- Run backups every day at midnight
- Run backups when your Mac boots/logs in (RunAtLoad=true)
- Run backups immediately after setup
- **Persist across restarts** - agents automatically reload on login

**Verify launch agents are loaded and will survive restart:**

```bash
# Check if agents are loaded
launchctl list | grep backup

# You should see entries like:
# com.example.backup-obsidian
# com.example.backup-personal-docs

# Run comprehensive verification
./verify-launchd.sh

# Check agent status and health
./health-check.sh
```

The verification script checks:
- Launch agent files exist
- Agents are loaded in launchd
- RunAtLoad is enabled (ensures restart persistence)
- Backup scripts are executable
- Schedule configuration is correct

**Test restart persistence:**

```bash
# Option 1: Test without restarting
launchctl unload ~/Library/LaunchAgents/com.example.backup-obsidian.plist
launchctl load ~/Library/LaunchAgents/com.example.backup-obsidian.plist
# Check logs to verify it ran on load

# Option 2: Full restart test
# 1. Note current time: date
# 2. Restart your Mac
# 3. After login, run: ./verify-launchd.sh
# 4. Check logs: grep "$(date +%Y-%m-%d)" logs/obsidian_backup.log
```

See [TESTING.md](TESTING.md) for comprehensive restart testing guide.

#### 6. View Launch Agent Logs

Logs are stored in the `logs` directory:

```bash
# View recent backup activity
tail -f logs/obsidian_backup.log

# View all logs
ls -lh logs/

# Check for errors
grep ERROR logs/*.log
```

#### 7. Manual Control of Launch Agents

```bash
# Unload an agent (stop automatic backups)
launchctl unload ~/Library/LaunchAgents/com.example.backup-obsidian.plist

# Reload an agent (resume automatic backups)
launchctl load ~/Library/LaunchAgents/com.example.backup-obsidian.plist

# Trigger a backup immediately
launchctl start com.example.backup-obsidian
```

### Troubleshooting on macOS

**"Permission denied" when running scripts:**
```bash
chmod +x backup-to-git.sh backup-obsidian.sh backup-personal-docs.sh health-check.sh
```

**Launch agent not running:**
```bash
# Check system logs
log show --predicate 'subsystem == "com.apple.launchd"' --last 1h | grep backup

# Verify plist file syntax
plutil -lint ~/Library/LaunchAgents/com.example.backup-obsidian.plist

# Reload the agent
launchctl unload ~/Library/LaunchAgents/com.example.backup-obsidian.plist
launchctl load ~/Library/LaunchAgents/com.example.backup-obsidian.plist
```

**"bash: local: can only be used in a function" error:**
This was a bug in earlier versions. Make sure you're using the latest version:
```bash
git pull origin main
```

**Notifications not appearing:**
- Check System Preferences → Notifications → Script Editor
- Make sure notifications are enabled
- Test with: `osascript -e 'display notification "Test" with title "Backup Test"'`

**Git authentication issues:**
```bash
# Use SSH instead of HTTPS for easier authentication
git remote set-url origin git@github.com:yourusername/repo.git

# Or configure git credential helper for HTTPS
git config --global credential.helper osxkeychain
```

### Best Practices for macOS

1. **Verify restart persistence after setup:**
   ```bash
   ./verify-launchd.sh
   ```

2. **Keep your Mac awake during backups** - Consider using [Amphetamine](https://apps.apple.com/us/app/amphetamine/id937984704) (free on App Store) or `caffeinate` command

3. **Test with dry-run first:**
   ```bash
   DRY_RUN=true ./backup-to-git.sh obsidian
   ```

4. **Run health checks regularly:**
   ```bash
   ./health-check.sh
   ```

5. **Monitor logs periodically:**
   ```bash
   grep ERROR logs/*.log
   ```

6. **Use SSH keys for git** - Set up SSH keys to avoid password prompts:
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   cat ~/.ssh/id_ed25519.pub
   # Add this to GitHub/GitLab SSH keys
   ```

### Quick Reference Commands

```bash
# Run manual backup
./backup-to-git.sh obsidian

# Run backup to specific branch
./backup-to-git.sh my-project dev

# Test without making changes
DRY_RUN=true ./backup-to-git.sh obsidian

# Check all backup jobs health
./health-check.sh

# Verify launch agents and restart persistence
./verify-launchd.sh

# View logs
tail -f logs/obsidian_backup.log

# List launch agents
launchctl list | grep backup

# Trigger immediate backup via launch agent
launchctl start com.example.backup-obsidian

# Test restart behavior without restarting
launchctl unload ~/Library/LaunchAgents/com.example.backup-obsidian.plist
launchctl load ~/Library/LaunchAgents/com.example.backup-obsidian.plist
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

**Branch Safety**: The script automatically ensures you're on the correct branch before pulling/pushing:

- If already on the target branch, continues with backup
- If on a different branch with no uncommitted changes, automatically switches
- If the target branch doesn't exist locally, creates it from `origin/<branch>`
- If there are uncommitted changes, fails with a clear error message

This prevents accidentally merging or pushing to the wrong branch.

**Example scenarios**:
```bash
# Currently on 'main', no uncommitted changes
./backup-to-git.sh my-project dev
# → Switches to 'dev', then backs up

# Currently on 'main', with uncommitted changes
./backup-to-git.sh my-project dev
# → Fails with error: "Cannot switch branches - uncommitted changes detected"
# → You must commit or stash changes first
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
