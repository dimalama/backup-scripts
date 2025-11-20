# Testing Backup Scripts After Restart

This guide helps you verify that your backup scripts will run automatically after your Mac restarts.

## Quick Verification

Run the verification script:

```bash
./verify-launchd.sh
```

This will check:
- ✓ Launch agent files exist
- ✓ Agents are loaded in launchd
- ✓ Plist syntax is valid
- ✓ RunAtLoad is enabled (runs on boot)
- ✓ Backup scripts exist and are executable
- ✓ Schedule configuration

## Step-by-Step Testing

### 1. Initial Setup

If you haven't set up launch agents yet:

```bash
# Make sure config.sh is configured
cp config.template.sh config.sh
# Edit config.sh with your paths

# Run the setup script
./setup-launchd.sh

# Verify the setup
./verify-launchd.sh
```

### 2. Test Immediate Execution

Trigger a backup manually to ensure it works:

```bash
# Trigger via launch agent
launchctl start com.example.backup-obsidian

# Wait a moment, then check logs
tail logs/obsidian_backup.log

# Or run the script directly
./backup-obsidian.sh
```

Expected output in logs:
```
2025-11-20 10:30:00 - [INFO] - Starting backup: Obsidian
2025-11-20 10:30:00 - [SUCCESS] - Backup completed successfully
```

### 3. Verify Launch Agents Are Loaded

Check that launchd knows about your agents:

```bash
launchctl list | grep backup
```

You should see:
```
-    0    com.example.backup-obsidian
-    0    com.example.backup-personal-docs
```

### 4. Check Agent Configuration

Inspect the actual plist files:

```bash
# View the configuration
cat ~/Library/LaunchAgents/com.example.backup-obsidian.plist

# Verify RunAtLoad is set
grep -A 1 "RunAtLoad" ~/Library/LaunchAgents/com.example.backup-obsidian.plist
```

Should show:
```xml
<key>RunAtLoad</key>
<true/>
```

This is **critical** - it means the agent will run when you log in after restart.

### 5. Test Restart Behavior

#### Option A: Full Restart Test

1. **Before restart:**
   ```bash
   # Note the current status
   launchctl list | grep backup > /tmp/before-restart.txt
   date >> /tmp/before-restart.txt
   ```

2. **Restart your Mac:**
   ```bash
   sudo shutdown -r now
   ```

3. **After restart and login:**
   ```bash
   # Check agents are loaded
   launchctl list | grep backup

   # Verify with the verification script
   ./verify-launchd.sh

   # Check if backups ran on login
   grep "$(date +%Y-%m-%d)" logs/obsidian_backup.log
   ```

#### Option B: Logout/Login Test (Faster)

1. **Log out** (don't restart)
2. **Log back in**
3. **Check if agents loaded:**
   ```bash
   launchctl list | grep backup
   tail logs/obsidian_backup.log
   ```

#### Option C: Simulate Without Restart

```bash
# Unload the agent (simulates logout)
launchctl unload ~/Library/LaunchAgents/com.example.backup-obsidian.plist

# Verify it's gone
launchctl list | grep backup-obsidian
# Should show nothing

# Load it again (simulates login)
launchctl load ~/Library/LaunchAgents/com.example.backup-obsidian.plist

# Check if it ran (RunAtLoad should trigger it)
tail logs/obsidian_backup.log

# Verify it's loaded
launchctl list | grep backup-obsidian
```

### 6. Monitor for 24 Hours

Check that the scheduled backups run:

```bash
# Check logs for the last 24 hours
grep "$(date -v-1d +%Y-%m-%d)\|$(date +%Y-%m-%d)" logs/obsidian_backup.log

# Count successful backups
grep "Backup completed successfully" logs/obsidian_backup.log | tail -5

# Check for any errors
grep ERROR logs/*.log
```

## Troubleshooting

### Agent Not Loading After Restart

```bash
# Check if the plist file exists
ls -l ~/Library/LaunchAgents/com.example.backup-*.plist

# Validate plist syntax
plutil -lint ~/Library/LaunchAgents/com.example.backup-obsidian.plist

# Check system logs for errors
log show --predicate 'subsystem == "com.apple.launchd"' --last 1h | grep backup

# Manually load the agent
launchctl load ~/Library/LaunchAgents/com.example.backup-obsidian.plist
```

### Agent Loads But Doesn't Run

```bash
# Check permissions on the script
ls -l backup-obsidian.sh
# Should show: -rwxr-xr-x

# Make it executable if needed
chmod +x backup-obsidian.sh

# Check if config.sh exists
ls -l config.sh

# Test the script directly
./backup-obsidian.sh
```

### Backups Run But Fail

```bash
# Check the logs for details
cat logs/obsidian_backup.log

# Common issues:
# 1. Directory doesn't exist
# 2. Not a git repository
# 3. No remote configured
# 4. Authentication failed

# Run health check
./health-check.sh
```

### Different User Account

Launch agents are user-specific. If you switch user accounts:

```bash
# Each user needs their own setup
whoami  # Check which user you are

# Run setup for this user
./setup-launchd.sh

# Verify for this user
./verify-launchd.sh
```

## Expected Behavior After Setup

Once properly configured, your backup scripts will:

1. ✅ Run **immediately on login** (RunAtLoad=true)
2. ✅ Run **daily at midnight** (StartCalendarInterval)
3. ✅ **Survive restarts** (persisted in ~/Library/LaunchAgents)
4. ✅ **Run even if you're not logged in** to the GUI (if using a launch daemon, but we use agents which require login)

**Note:** macOS LaunchAgents require you to be logged in. They run when you log in and stop when you log out. If you need backups to run even when not logged in, you'd need a LaunchDaemon (requires admin/root).

## Monitoring Tips

### Set Up Daily Checks

Add to your shell profile (`~/.zshrc` or `~/.bash_profile`):

```bash
# Check backup status on login
alias backup-status='~/backup-scripts/verify-launchd.sh'
alias backup-health='~/backup-scripts/health-check.sh'
alias backup-logs='tail -f ~/backup-scripts/logs/*.log'
```

### macOS Notification Test

Ensure notifications work:

```bash
osascript -e 'display notification "Backup test successful" with title "Backup Scripts"'
```

If this works, you'll get notifications when backups succeed or fail.

## Summary Checklist

- [ ] Run `./setup-launchd.sh` to create launch agents
- [ ] Run `./verify-launchd.sh` to verify configuration
- [ ] Test manual trigger: `launchctl start com.example.backup-obsidian`
- [ ] Check logs: `tail logs/obsidian_backup.log`
- [ ] Verify loaded: `launchctl list | grep backup`
- [ ] Test restart behavior (logout/login or full restart)
- [ ] Verify agents reload after restart
- [ ] Monitor for 24 hours to confirm scheduled runs
- [ ] Set up monitoring aliases in shell profile

## Success Criteria

Your setup is successful when:

1. ✅ `./verify-launchd.sh` shows all checks passed
2. ✅ `launchctl list | grep backup` shows your agents
3. ✅ After restart, agents automatically reload
4. ✅ Logs show successful backups after login
5. ✅ Daily backups run at midnight
6. ✅ `./health-check.sh` shows all jobs healthy

## Need Help?

If you're still having issues after following this guide:

1. Run the verification script: `./verify-launchd.sh`
2. Check the health of your backup jobs: `./health-check.sh`
3. Review the logs: `cat logs/*.log`
4. Check system logs: `log show --predicate 'subsystem == "com.apple.launchd"' --last 1h | grep backup`

The verification script will give you specific commands to fix any issues it finds.
