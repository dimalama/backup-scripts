# Backup Scripts

A collection of shell scripts for automated backups using Git.

## Setup

1. Clone this repository
2. Copy `config.template.sh` to `config.sh` and update the paths:
   ```bash
   cp config.template.sh config.sh
   ```
3. Edit `config.sh` with your paths and Git configuration
4. For automated backups on macOS:
   - Copy the template plist file:
     ```bash
     cp com.example.backup-obsidian.template.plist ~/Library/LaunchAgents/com.username.backup-obsidian.plist
     ```
   - Edit the plist file with your paths
   - Load the launchd job:
     ```bash
     launchctl load ~/Library/LaunchAgents/com.username.backup-obsidian.plist
     ```

## Scripts

- `backup-obsidian.sh`: Backs up an Obsidian vault to Git
- `backup-personal-docs.sh`: Backs up personal documents to Git

## Configuration

Update the following variables in `config.sh`:

- `BACKUP_SCRIPTS_DIR`: Path to this backup scripts directory
- `OBSIDIAN_DIR`: Path to your Obsidian vault
- `PERSONAL_DOCS_DIR`: Path to your personal documents
- `GIT_USER_EMAIL`: Your Git email (optional)
- `GIT_USER_NAME`: Your Git username (optional)

## Logs

Logs are stored in the `logs` directory and are excluded from Git.
