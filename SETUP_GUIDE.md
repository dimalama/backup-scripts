# Backup Scripts - Complete Setup Guide

This guide walks you through setting up automated daily backups with restart persistence on macOS.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Configure Automated Backups](#configure-automated-backups)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

## Prerequisites

### 1. Install Modern Bash

macOS ships with bash 3.2.57, but these scripts require bash 4.0+ for associative arrays.

```bash
# Install bash 5.x via Homebrew
brew install bash

# Verify installation
/usr/local/bin/bash --version  # Intel Mac
# Should show: GNU bash, version 5.x.x

/opt/homebrew/bin/bash --version  # Apple Silicon
# Should show: GNU bash, version 5.x.x
```

### 2. Verify Git is Installed

```bash
git --version
# Should show: git version 2.x.x or higher
```

### 3. Required Tools

```bash
# These should already be installed on macOS
which timeout  # For git operation timeouts
which launchctl  # For scheduling backups
which xattr  # For iCloud exclusions
```

## Initial Setup

### Step 1: Clone or Download This Repository

```bash
cd ~/Projects
git clone <your-repo-url> backup-scripts
cd backup-scripts
```

### Step 2: Create Configuration File

```bash
# Copy the template
cp config.template.sh config.sh

# Edit configuration with your settings
nano config.sh  # or use your preferred editor
```

**Important settings to configure:**

```bash
# Update these in config.sh:
export BACKUP_SCRIPTS_DIR="$HOME/Projects/backup-scripts"  # Current directory
export GIT_USER_EMAIL="your-email@example.com"
export GIT_USER_NAME="Your Name"

# Configure backup jobs
BACKUP_JOBS[obsidian]="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyBrain"
BACKUP_JOBS[personal-docs]="/Volumes/External/Personal"
# Add more as needed
```

### Step 3: Initialize Git Repositories

For each directory you want to back up:

```bash
# Navigate to the directory
cd "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyBrain"

# Initialize git if not already done
git init
git add .
git commit -m "Initial commit"

# Add remote repository
git remote add origin <your-remote-repo-url>
git branch -M main
git push -u origin main
```

### Step 4: Fix iCloud + Git Conflicts

If backing up directories in iCloud Drive, exclude `.git` from sync:

```bash
# For Obsidian vault in iCloud
xattr -w com.apple.fileprovider.ignore_sync 1 "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyBrain/.git"

# Verify the attribute is set
xattr "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyBrain/.git"
# Should show: com.apple.fileprovider.ignore_sync

# Clean up any existing lock files
rm -f "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyBrain/.git/index.lock"
```

**Why this is needed:** iCloud Drive tries to sync the `.git` directory while git operations are running, causing conflicts and hanging. This exclusion prevents that.

## Configure Automated Backups

### Step 1: Update LaunchAgent Files

The repository includes template plist files. You need to customize them:

```bash
# Check your username
whoami
# Example output: dlukianenko

# Update the plist files with your paths
# Edit these files:
# - com.dlukianenko.backup-obsidian.plist
# - com.dlukianenko.backup-personal-docs.plist

# Make sure they use the correct:
# 1. Bash path: /usr/local/bin/bash (Intel) or /opt/homebrew/bin/bash (Apple Silicon)
# 2. Script paths: /Users/YOUR_USERNAME/Projects/backup-scripts/...
# 3. Log paths: /Users/YOUR_USERNAME/Projects/backup-scripts/logs/...
```

### Step 2: Install LaunchAgents

```bash
# Create LaunchAgents directory if it doesn't exist
mkdir -p ~/Library/LaunchAgents

# Copy plist files
cp com.dlukianenko.backup-obsidian.plist ~/Library/LaunchAgents/
cp com.dlukianenko.backup-personal-docs.plist ~/Library/LaunchAgents/

# Set correct permissions
chmod 644 ~/Library/LaunchAgents/com.dlukianenko.backup-*.plist
```

### Step 3: Load the Agents

```bash
# Load Obsidian backup agent
launchctl load ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist

# Load personal docs backup agent
launchctl load ~/Library/LaunchAgents/com.dlukianenko.backup-personal-docs.plist
```

### Step 4: Verify Agents are Loaded

```bash
# Check agents are loaded
launchctl list | grep dlukianenko

# Expected output:
# -  0  com.dlukianenko.backup-obsidian
# -  0  com.dlukianenko.backup-personal-docs
```

## Testing

### Test 1: Manual Backup Test

```bash
# Test Obsidian backup manually
./backup-obsidian.sh

# Check the logs
tail -20 logs/obsidian_backup.log

# Look for:
# - "Backup completed successfully" (SUCCESS)
# - No ERROR messages
```

### Test 2: Dry-Run Mode Test

```bash
# Test without making changes
DRY_RUN=true ./backup-to-git.sh obsidian

# Check logs for:
# - "DRY RUN: Would commit and push changes"
# - No actual commits should be made
```

### Test 3: Generic Backup Script Test

```bash
# Test the generic script (uses config.sh)
./backup-to-git.sh obsidian

# Verify it works the same as the legacy script
```

### Test 4: LaunchAgent Test

```bash
# Check if agent ran on load (RunAtLoad=true)
tail -30 logs/obsidian_backup.log

# Look for recent timestamp entries
# If agents just loaded, you should see new entries
```

### Test 5: Restart Persistence Test

**Option 1: Test without restarting**

```bash
# Unload the agent
launchctl unload ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist

# Verify it's unloaded
launchctl list | grep dlukianenko
# Should NOT show backup-obsidian

# Reload it
launchctl load ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist

# Verify it loaded and ran
launchctl list | grep dlukianenko
tail -10 logs/obsidian_backup.log
```

**Option 2: Full restart test**

```bash
# Before restart - verify agents are loaded
launchctl list | grep dlukianenko > /tmp/pre-restart-agents.txt

# Restart your Mac
sudo shutdown -r now

# After login - verify agents auto-loaded
launchctl list | grep dlukianenko > /tmp/post-restart-agents.txt

# Compare (should be identical)
diff /tmp/pre-restart-agents.txt /tmp/post-restart-agents.txt

# Check if backup ran on login
tail -20 logs/obsidian_backup.log
# Look for entries with timestamp right after login
```

### Test 6: Schedule Test

```bash
# Check when next backup will run
launchctl print gui/$(id -u)/com.dlukianenko.backup-obsidian | grep -A5 "StartCalendarInterval"

# Agents are configured to run at midnight (00:00)
# Wait until after midnight and check logs:
tail -30 logs/obsidian_backup.log | grep "$(date +%Y-%m-%d)"
```

### Test 7: Health Check

```bash
# Run the health check script
./health-check.sh

# This checks:
# - If backup directories exist
# - If they are git repositories
# - If remote repositories are configured
# - Recent backup status
```

## Troubleshooting

### Issue: Backup hangs or times out

**Symptoms:**
- Script runs for 5+ minutes and times out
- Log shows "Adding changes to git index..." but never completes

**Solution:**
```bash
# Check if directory is in iCloud
# If yes, exclude .git from iCloud sync
xattr -w com.apple.fileprovider.ignore_sync 1 /path/to/backup/.git

# Remove stale lock files
rm -f /path/to/backup/.git/index.lock

# Test again
DRY_RUN=true ./backup-to-git.sh <backup-name>
```

### Issue: "declare: -A: invalid option"

**Symptoms:**
- Error when running any backup script
- Bash version is 3.2.57

**Solution:**
```bash
# Install modern bash
brew install bash

# Verify all scripts use /usr/local/bin/bash
head -1 *.sh lib/*.sh

# Should all show: #!/usr/local/bin/bash (Intel)
# or: #!/opt/homebrew/bin/bash (Apple Silicon)
```

### Issue: LaunchAgent doesn't run after restart

**Symptoms:**
- Agents are loaded but don't run on login
- No recent entries in logs after restart

**Checklist:**
```bash
# 1. Verify plist file location
ls -la ~/Library/LaunchAgents/com.dlukianenko.backup-*.plist

# 2. Verify permissions
# Should be: -rw-r--r-- (644)
chmod 644 ~/Library/LaunchAgents/com.dlukianenko.backup-*.plist

# 3. Check plist syntax
plutil ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist
# Should output: OK

# 4. Verify RunAtLoad is set
plutil -p ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist | grep RunAtLoad
# Should show: "RunAtLoad" => 1

# 5. Check launchd logs
log show --predicate 'subsystem == "com.apple.launchd"' --last 1h | grep backup

# 6. Reload agent
launchctl unload ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist
launchctl load ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist
```

### Issue: "Failed to commit changes"

**Symptoms:**
- Log shows "Failed to commit changes"
- May mention "index.lock" file exists

**Solution:**
```bash
# Clean up lock files
find /path/to/backup -name "*.lock" -delete

# Or manually:
rm -f /path/to/backup/.git/index.lock

# The scripts now do this automatically, but you can do it manually if needed
```

### Issue: DRY_RUN doesn't work

**Symptoms:**
- Setting `DRY_RUN=true` still commits changes

**Solution:**
```bash
# Check config.sh has the correct syntax
grep "DRY_RUN" config.sh

# Should be:
# export DRY_RUN="${DRY_RUN:-false}"

# NOT:
# export DRY_RUN=false

# If wrong, fix it:
sed -i '' 's/^export DRY_RUN=false$/export DRY_RUN="${DRY_RUN:-false}"/' config.sh
```

## Maintenance

### Daily Tasks

None required - backups run automatically!

### Weekly Tasks

```bash
# Check backup health
./health-check.sh

# Review logs for any errors
grep ERROR logs/*.log

# Check disk space in logs directory
du -sh logs/
```

### Monthly Tasks

```bash
# Update backup scripts if needed
cd ~/Projects/backup-scripts
git pull

# Verify remote repositories are accessible
cd /path/to/backup
git fetch --dry-run

# Review and clean old rotated logs
ls -lh logs/*.log.*
# Logs auto-rotate when they exceed 10MB
# Keep last 10 rotations per the log rotation policy
```

### Updating Configuration

```bash
# After changing config.sh, reload agents:
launchctl unload ~/Library/LaunchAgents/com.dlukianenko.backup-*.plist
launchctl load ~/Library/LaunchAgents/com.dlukianenko.backup-*.plist

# Or restart them individually
launchctl kickstart -k gui/$(id -u)/com.dlukianenko.backup-obsidian
```

### Adding New Backup Jobs

```bash
# 1. Edit config.sh
nano config.sh

# 2. Add new backup job
# BACKUP_JOBS[my-new-backup]="/path/to/directory"

# 3. Initialize git in that directory
cd /path/to/directory
git init
git add .
git commit -m "Initial commit"
git remote add origin <remote-url>
git push -u origin main

# 4. Test manually
./backup-to-git.sh my-new-backup

# 5. (Optional) Create dedicated LaunchAgent
# Copy and modify existing plist file
cp com.dlukianenko.backup-obsidian.plist com.dlukianenko.backup-my-new-backup.plist
# Edit the new file to point to new backup job
# Load it
launchctl load ~/Library/LaunchAgents/com.dlukianenko.backup-my-new-backup.plist
```

## Advanced Configuration

### Change Backup Schedule

Edit the plist file and modify `StartCalendarInterval`:

```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>14</integer>  <!-- 2 PM -->
    <key>Minute</key>
    <integer>30</integer>  <!-- 30 minutes -->
</dict>
```

Or run multiple times per day:

```xml
<key>StartCalendarInterval</key>
<array>
    <dict>
        <key>Hour</key>
        <integer>9</integer>  <!-- 9 AM -->
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <dict>
        <key>Hour</key>
        <integer>18</integer>  <!-- 6 PM -->
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</array>
```

After editing, reload:

```bash
launchctl unload ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist
launchctl load ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist
```

### Enable Notifications

Edit `config.sh`:

```bash
# macOS Notifications
export ENABLE_MACOS_NOTIFICATIONS=true

# Email Notifications
export ENABLE_EMAIL_NOTIFICATIONS=true
export NOTIFICATION_EMAIL="your-email@example.com"

# Webhook Notifications (Slack, Discord, etc.)
export ENABLE_WEBHOOK_NOTIFICATIONS=true
export WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### Disable Backup Verification

To skip verification that backups were pushed (faster but less safe):

```bash
# Edit config.sh
export VERIFY_BACKUP=false
```

## Quick Reference

### Common Commands

```bash
# Manual backup
./backup-obsidian.sh
./backup-to-git.sh obsidian

# Dry-run test
DRY_RUN=true ./backup-to-git.sh obsidian

# Check status
launchctl list | grep dlukianenko
./health-check.sh

# View logs
tail -f logs/obsidian_backup.log
tail -f logs/launchd.log

# Restart agents
launchctl kickstart -k gui/$(id -u)/com.dlukianenko.backup-obsidian

# Unload/reload agents
launchctl unload ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist
launchctl load ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist
```

### Important File Locations

```
~/Projects/backup-scripts/                          # Main directory
├── config.sh                                       # Your configuration
├── backup-to-git.sh                               # Generic backup script
├── backup-obsidian.sh                             # Legacy Obsidian backup
├── lib/backup-functions.sh                        # Shared functions
├── logs/                                          # All backup logs
│   ├── obsidian_backup.log                       # Obsidian backup log
│   ├── personal_docs_backup.log                  # Personal docs log
│   └── launchd.log                               # LaunchAgent output
└── com.dlukianenko.backup-*.plist                # Agent definitions

~/Library/LaunchAgents/                            # Installed agents
├── com.dlukianenko.backup-obsidian.plist
└── com.dlukianenko.backup-personal-docs.plist
```

## Security Notes

1. **Credentials**: These scripts don't store any credentials. Git credentials are managed by your system's credential helper (usually Keychain on macOS).

2. **SSH Keys**: If using SSH for git, ensure your SSH keys are loaded in the SSH agent or use 1Password's SSH agent.

3. **File Permissions**: Backup directories should only be readable by your user account.

4. **Remote Repositories**: Use private repositories for personal data backups.

## Support

For issues or questions:

1. Check this guide's [Troubleshooting](#troubleshooting) section
2. Review logs: `tail -50 logs/obsidian_backup.log`
3. Check [README.md](README.md) for additional documentation
4. Open an issue in the repository

---

**Last Updated:** 2025-11-20
