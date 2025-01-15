# Backup Scripts

A collection of shell scripts for automated backups using Git.

## Setup

1. Clone this repository
2. Copy `config.template.sh` to `config.sh` and update the paths:
   ```bash
   cp config.template.sh config.sh
   ```
3. Edit `config.sh` with your paths and Git configuration

### Setting up Automated Backups (macOS)

1. Copy the setup script template:
   ```bash
   cp setup-launchd.template.sh setup-launchd.sh
   chmod +x setup-launchd.sh
   ```

2. Run the setup script to configure and load the launch agents:
   ```bash
   ./setup-launchd.sh
   ```

This will:
- Create launch agent files in `~/Library/LaunchAgents/`
- Configure them with your paths from `config.sh`
- Load them into launchd

The backups will run:
- Every day at midnight
- When your system boots
- Immediately after setup

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

## Launch Agents

The launch agents are configured to:
- Run backups daily at midnight
- Run on system boot
- Keep logs in the `logs` directory

You can modify the schedule by editing the `StartCalendarInterval` in the plist files.

## Logs

Logs are stored in the `logs` directory and are excluded from Git.
