# Backup Scripts - Testing Checklist

Use this checklist to verify your backup setup is working correctly.

## Initial Setup Testing

### ✅ Prerequisites Check

```bash
# [ ] Bash 5.x is installed
/usr/local/bin/bash --version
# Expected: GNU bash, version 5.x.x

# [ ] Git is available
git --version
# Expected: git version 2.x.x or higher

# [ ] Config file exists
ls -l config.sh
# Expected: File exists

# [ ] Scripts are executable
ls -l *.sh
# Expected: -rwxr-xr-x (755 permissions)
```

### ✅ Configuration Check

```bash
# [ ] Backup jobs are defined in config.sh
grep "BACKUP_JOBS\[" config.sh
# Expected: At least one backup job defined

# [ ] Git user is configured
grep "GIT_USER" config.sh
# Expected: GIT_USER_EMAIL and GIT_USER_NAME set

# [ ] DRY_RUN respects environment variable
grep "DRY_RUN" config.sh
# Expected: export DRY_RUN="${DRY_RUN:-false}"
```

### ✅ Git Repository Check

For each backup directory:

```bash
# [ ] Directory exists
ls -ld "/path/to/backup"
# Expected: Directory exists and is accessible

# [ ] It's a git repository
cd "/path/to/backup" && git rev-parse --git-dir
# Expected: .git

# [ ] Remote is configured
git remote -v
# Expected: origin with push/fetch URLs

# [ ] Can fetch from remote
git fetch --dry-run
# Expected: No errors
```

### ✅ iCloud Configuration (if applicable)

```bash
# [ ] .git is excluded from iCloud sync
xattr "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyBrain/.git"
# Expected: com.apple.fileprovider.ignore_sync

# [ ] No lock files exist
find "/path/to/backup/.git" -name "*.lock"
# Expected: No files found
```

## Manual Backup Testing

### ✅ Test 1: Dry-Run Mode

```bash
# [ ] Dry-run completes without errors
DRY_RUN=true ./backup-to-git.sh obsidian
echo "Exit code: $?"
# Expected: Exit code 0

# [ ] Log shows dry-run message
tail -10 logs/obsidian_backup.log | grep "DRY RUN"
# Expected: "DRY RUN: Would commit and push changes"

# [ ] No actual commits were made
cd "/path/to/backup" && git log -1 --format="%cd"
# Expected: Timestamp should be old (before this test)
```

### ✅ Test 2: Real Backup

```bash
# [ ] Create test change
echo "Test $(date)" >> "/path/to/backup/TEST_FILE.txt"

# [ ] Run backup
./backup-to-git.sh obsidian
echo "Exit code: $?"
# Expected: Exit code 0

# [ ] Check logs for success
tail -20 logs/obsidian_backup.log | grep -E "SUCCESS|ERROR"
# Expected: "Backup completed successfully" (SUCCESS)
# Expected: No ERROR messages

# [ ] Verify commit was created
cd "/path/to/backup" && git log -1 --oneline
# Expected: Shows recent commit with "Automated backup" message

# [ ] Verify push succeeded
git log origin/main..HEAD
# Expected: No commits (empty output = everything pushed)

# [ ] Clean up test file
rm "/path/to/backup/TEST_FILE.txt"
```

### ✅ Test 3: No Changes Scenario

```bash
# [ ] Run backup with no changes
./backup-to-git.sh obsidian
echo "Exit code: $?"
# Expected: Exit code 0

# [ ] Check log message
tail -10 logs/obsidian_backup.log | grep "No changes"
# Expected: "No changes to commit" or "Backup completed: no changes detected"
```

### ✅ Test 4: Generic vs Legacy Scripts

```bash
# [ ] Both scripts work the same
./backup-obsidian.sh
LEGACY_EXIT=$?

./backup-to-git.sh obsidian
GENERIC_EXIT=$?

echo "Legacy: $LEGACY_EXIT, Generic: $GENERIC_EXIT"
# Expected: Both should be 0
```

## LaunchAgent Testing

### ✅ Test 5: Agent Installation

```bash
# [ ] Agent files exist in LaunchAgents
ls -l ~/Library/LaunchAgents/com.dlukianenko.backup-*.plist
# Expected: At least 2 files (obsidian and personal-docs)

# [ ] Permissions are correct (644)
stat -f "%OLp" ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist
# Expected: 644

# [ ] Plist files are valid
plutil ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist
# Expected: OK

# [ ] Agents are loaded
launchctl list | grep dlukianenko
# Expected: Shows both backup agents
# Expected: Exit code 0 (no errors)
```

### ✅ Test 6: Agent Configuration

```bash
# [ ] RunAtLoad is enabled
plutil -p ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist | grep RunAtLoad
# Expected: "RunAtLoad" => 1

# [ ] Uses modern bash
plutil -p ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist | grep -A2 ProgramArguments
# Expected: First element is /usr/local/bin/bash

# [ ] Schedule is correct
plutil -p ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist | grep -A5 StartCalendarInterval
# Expected: Hour => 0, Minute => 0 (midnight)

# [ ] Paths are correct
plutil -p ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist | grep backup-scripts
# Expected: Shows correct absolute paths to scripts and logs
```

### ✅ Test 7: Agent Execution

```bash
# [ ] Agent details show correct state
launchctl print gui/$(id -u)/com.dlukianenko.backup-obsidian | head -20
# Expected: Shows agent information
# Expected: program = /usr/local/bin/bash

# [ ] Recent backup occurred
ls -lt logs/obsidian_backup.log
tail -5 logs/obsidian_backup.log
# Expected: Recent timestamp (within last hour if just loaded)

# [ ] LaunchAgent stdout/stderr logs
tail -10 logs/launchd.log 2>/dev/null
tail -10 logs/launchd.error.log 2>/dev/null
# Expected: No critical errors
```

### ✅ Test 8: Manual Agent Trigger

```bash
# [ ] Can manually trigger agent
launchctl kickstart -k gui/$(id -u)/com.dlukianenko.backup-obsidian
echo "Exit code: $?"
# Expected: Exit code 0

# [ ] Wait a few seconds
sleep 10

# [ ] Check that backup ran
tail -10 logs/obsidian_backup.log | grep "$(date +%Y-%m-%d)"
# Expected: Shows today's date in recent log entry
```

### ✅ Test 9: Unload/Reload Test

```bash
# [ ] Unload agent
launchctl unload ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist
echo "Exit code: $?"
# Expected: Exit code 0

# [ ] Verify unloaded
launchctl list | grep backup-obsidian
echo "Exit code: $?"
# Expected: Exit code 1 (not found)

# [ ] Reload agent
launchctl load ~/Library/LaunchAgents/com.dlukianenko.backup-obsidian.plist
echo "Exit code: $?"
# Expected: Exit code 0

# [ ] Verify loaded
launchctl list | grep backup-obsidian
# Expected: Shows backup-obsidian with exit code 0

# [ ] Check if RunAtLoad triggered backup
tail -10 logs/obsidian_backup.log
# Expected: New log entry from the reload
```

## Restart Persistence Testing

### ✅ Test 10: Pre-Restart Verification

```bash
# [ ] Record current state before restart
launchctl list | grep dlukianenko > /tmp/pre-restart-agents.txt
cat /tmp/pre-restart-agents.txt
# Expected: Shows both backup agents loaded

# [ ] Note current log timestamps
echo "Obsidian last backup:" > /tmp/pre-restart-times.txt
tail -1 logs/obsidian_backup.log >> /tmp/pre-restart-times.txt
echo "Personal docs last backup:" >> /tmp/pre-restart-times.txt
tail -1 logs/personal_docs_backup.log >> /tmp/pre-restart-times.txt
cat /tmp/pre-restart-times.txt
# Expected: Shows last backup times
```

### ✅ Test 11: Restart the System

```bash
# [ ] Restart your Mac
# Option 1: Clean restart
sudo shutdown -r now

# Option 2: Just log out and back in
# GUI: Apple menu > Log Out
```

### ✅ Test 12: Post-Restart Verification

```bash
# [ ] Verify agents auto-loaded after restart
launchctl list | grep dlukianenko > /tmp/post-restart-agents.txt
cat /tmp/post-restart-agents.txt
# Expected: Shows both backup agents (same as pre-restart)

# [ ] Compare pre and post restart states
diff /tmp/pre-restart-agents.txt /tmp/post-restart-agents.txt
# Expected: Should be identical or very similar

# [ ] Check if backups ran after login (RunAtLoad)
tail -10 logs/obsidian_backup.log
tail -10 logs/personal_docs_backup.log
# Expected: New entries with timestamps after system boot time

# [ ] Verify boot time vs backup time
who -b  # System boot time
tail -1 logs/obsidian_backup.log | awk '{print $1, $2, $3}'
# Expected: Backup time should be AFTER boot time
```

## Error Handling Testing

### ✅ Test 13: Timeout Protection

```bash
# [ ] This test requires a slow operation - skip if not needed

# Create a large test file (optional)
# dd if=/dev/zero of="/path/to/backup/large_file.tmp" bs=1m count=100

# Run backup and verify it doesn't hang forever
# Should complete or timeout within 5 minutes
timeout 400 ./backup-to-git.sh obsidian
echo "Exit code: $?"
# Expected: Completes successfully or times out gracefully
```

### ✅ Test 14: Lock File Handling

```bash
# [ ] Create a fake lock file
touch "/path/to/backup/.git/index.lock"

# [ ] Verify lock file exists
ls -l "/path/to/backup/.git/index.lock"
# Expected: File exists

# [ ] Run backup (should auto-clean lock file)
./backup-to-git.sh obsidian
echo "Exit code: $?"
# Expected: Exit code 0 (success)

# [ ] Check log for lock file cleanup
grep "Removing stale git lock file" logs/obsidian_backup.log | tail -1
# Expected: Shows warning about removing lock file

# [ ] Verify lock file was removed
ls "/path/to/backup/.git/index.lock" 2>&1
# Expected: No such file or directory
```

### ✅ Test 15: Missing Directory Handling

```bash
# [ ] Test with non-existent backup job
./backup-to-git.sh non-existent-backup 2>&1
echo "Exit code: $?"
# Expected: Exit code 1 (failure)
# Expected: Error message about backup job not found

# [ ] Check available backup jobs are listed
./backup-to-git.sh non-existent-backup 2>&1 | grep "Available backup jobs"
# Expected: Lists configured backup jobs
```

## Health Check Testing

### ✅ Test 16: Health Check Script

```bash
# [ ] Run health check
./health-check.sh
echo "Exit code: $?"
# Expected: Exit code 0 if everything is healthy

# Expected output should show:
# - Backup directories status
# - Git repository status
# - Remote configuration
# - Recent backup success/failure
```

## Performance Testing

### ✅ Test 17: Backup Speed

```bash
# [ ] Time a full backup
time ./backup-to-git.sh obsidian
# Expected: Should complete in under 2 minutes for typical vault
# Expected: No timeout messages

# [ ] Time a no-changes backup
time ./backup-to-git.sh obsidian
# Expected: Should complete in under 10 seconds
```

### ✅ Test 18: Log Rotation

```bash
# [ ] Check log file size
ls -lh logs/obsidian_backup.log
# Expected: File size shown

# [ ] Verify rotation happens at 10MB
# (This test requires waiting for logs to grow naturally)
# ls -lh logs/obsidian_backup.log.*
# Expected: Rotated logs exist if main log exceeded 10MB
```

## Final Verification

### ✅ Complete System Check

```bash
# [ ] All scripts use modern bash
head -1 *.sh lib/*.sh | grep "#!/usr/local/bin/bash"
# Expected: All scripts show modern bash shebang

# [ ] No ERROR in recent logs
grep ERROR logs/*.log | tail -20
# Expected: No critical errors (or only expected errors like missing external drives)

# [ ] Agents are healthy
launchctl list | grep dlukianenko | awk '{print $1, $2, $3}'
# Expected: Both agents with exit code 0

# [ ] Recent backups succeeded
tail -1 logs/obsidian_backup.log | grep SUCCESS
# Expected: Shows SUCCESS

# [ ] Git repositories are clean
cd "/path/to/backup" && git status
# Expected: Working tree clean or shows untracked files only
```

## Testing Summary Template

After completing all tests, record your results:

```
Date: ___________
Tested by: ___________

✅ Prerequisites: PASS / FAIL
✅ Configuration: PASS / FAIL
✅ Manual Backups: PASS / FAIL
✅ LaunchAgents: PASS / FAIL
✅ Restart Persistence: PASS / FAIL
✅ Error Handling: PASS / FAIL
✅ Health Check: PASS / FAIL
✅ Performance: PASS / FAIL

Notes:
_________________________________
_________________________________
_________________________________

Issues Found:
_________________________________
_________________________________
_________________________________

Resolved:
_________________________________
_________________________________
_________________________________
```

## Continuous Monitoring

### Daily

- [ ] Check for ERROR in logs: `grep ERROR logs/*.log | tail -5`

### Weekly

- [ ] Run health check: `./health-check.sh`
- [ ] Verify recent backups: `tail -1 logs/*.log`

### Monthly

- [ ] Verify restart persistence (after OS updates)
- [ ] Test backup restoration
- [ ] Check disk space: `du -sh logs/`

---

**Quick Test Command:**

```bash
# Run all quick checks in one command
echo "=== Quick Health Check ===" && \
/usr/local/bin/bash --version && \
echo "✅ Bash version OK" && \
grep "DRY_RUN" config.sh && \
echo "✅ Config OK" && \
launchctl list | grep dlukianenko && \
echo "✅ Agents loaded" && \
tail -1 logs/obsidian_backup.log | grep -E "SUCCESS|completed" && \
echo "✅ Recent backup OK" && \
echo "=== All checks passed! ==="
```

---

**Last Updated:** 2025-11-20
