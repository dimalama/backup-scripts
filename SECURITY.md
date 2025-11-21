# Security Guidelines

This repository is designed to be safe for public sharing. Follow these guidelines to ensure no sensitive information is exposed.

## Files That Should NEVER Be Committed

The following files are automatically ignored by `.gitignore`:

### 1. Configuration Files
- **`config.sh`** - Contains your specific paths and settings
  - Use `config.template.sh` as a template
  - Never commit your actual `config.sh`

### 2. User-Specific LaunchAgent Files
- **`com.<username>.*.plist`** - Contains your username and absolute paths
  - Templates are OK: `com.example.*.plist`
  - Actual configured files should stay local

### 3. Documentation with User Info
- **`SESSION_SUMMARY.md`** - May contain usernames, paths, timestamps
  - This file is generated per session
  - Reference the templates instead

### 4. Claude Code Settings
- **`.claude/settings.local.json`** - Contains user-specific paths and permissions
  - Shared Claude configs are OK: `.claude/claude.json`, `.claude/commands/*`

### 5. Logs and Runtime Data
- **`logs/`** directory - Contains backup logs with timestamps
- **`*.log`** files - May contain file paths and commit messages
- **`.DS_Store`** - macOS metadata files

## What IS Safe to Commit

✅ **Template Files**
- `config.template.sh`
- `com.example.backup-obsidian.template.plist`
- `com.example.backup-personal-docs.template.plist`

✅ **Scripts**
- All `.sh` files (they use template/variable paths)
- `lib/backup-functions.sh`

✅ **Documentation**
- `README.md`
- `SETUP_GUIDE.md`
- `TESTING_CHECKLIST.md`
- Other `.md` files (except SESSION_SUMMARY.md)

✅ **Shared Claude Configs**
- `.claude/claude.json`
- `.claude/commands/*.md`

✅ **IDE Settings** (if generic)
- `.vscode/settings.json` (color themes, etc.)

## Before Committing - Security Checklist

Run this before every commit:

```bash
# 1. Check git status
git status

# 2. Verify no sensitive files are staged
git diff --cached --name-only | grep -E "config.sh|com\.[^e].*\.plist|SESSION_SUMMARY|settings.local"
# Should return nothing

# 3. Check for hardcoded credentials
git diff --cached | grep -iE "password|api_key|secret|token" | grep -v "example"
# Should return nothing

# 4. Check for email addresses
git diff --cached | grep "@" | grep -v "example.com"
# Should only show safe examples

# 5. Check for absolute paths with usernames
git diff --cached | grep "/Users/" | grep -v "YOUR_USERNAME\|yourusername\|username"
# Should return nothing
```

## What to Do If You Accidentally Commit Sensitive Data

### If not yet pushed:

```bash
# Remove the file from the last commit
git reset HEAD~1
# Or amend the commit
git commit --amend
```

### If already pushed to GitHub:

```bash
# Remove file from git history entirely
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch path/to/sensitive/file" \
  --prune-empty --tag-name-filter cat -- --all

# Force push (⚠️ DANGEROUS - notifies all collaborators)
git push origin --force --all
```

**Better approach:** Use GitHub's support to purge the file:
- Go to Settings > Support
- Request sensitive data removal
- GitHub will help clean the history

### After removing:

1. Update `.gitignore` to prevent future commits
2. Rotate any exposed credentials
3. Update remote repository URLs if needed
4. Notify collaborators if this was a shared repo

## Sensitive Data Types

### ❌ Never Commit

- **Usernames** - Use placeholders like `YOUR_USERNAME`
- **Email addresses** - Use `your-email@example.com`
- **Absolute paths** - Use `$HOME` or `/path/to/directory`
- **Repository URLs** - Use examples like `https://github.com/yourusername/repo.git`
- **API keys or tokens** - Never, ever
- **Passwords** - Obviously
- **Private git repository URLs** - Shows repo names and organization

### ✅ Safe to Include

- **Generic examples** - "your-email@example.com"
- **Template paths** - "/path/to/backup-scripts"
- **Variable references** - "$HOME", "$USER"
- **Public examples** - GitHub repository structure

## Git Configuration

Your `.gitignore` should include:

```gitignore
# User-specific configuration
config.sh

# User-specific launchd plist files
com.*.plist
!com.example.*.plist  # Allow templates

# Session-specific documentation
SESSION_SUMMARY.md

# Claude Code settings
.claude/settings.local.json

# Log files
logs/
*.log
*.log.*

# macOS
.DS_Store

# Backup files
*.bak
*~

# Temporary files
*.tmp
*.swp
```

## Regular Security Audits

Run these commands periodically:

```bash
# Find all tracked files
git ls-files

# Search for potential secrets
git grep -iE "password|api_key|secret|token" -- ':!SECURITY.md'

# Find email addresses
git grep "@" -- ':!*.md' ':!*.template.*'

# Find absolute paths with usernames
git grep -E "/Users/[^/]+" -- ':!SECURITY.md' ':!*.md'
```

## Repository Settings

On GitHub, configure:

1. **Branch Protection**
   - Require pull request reviews
   - Enable status checks

2. **Security Alerts**
   - Enable Dependabot alerts
   - Enable secret scanning (GitHub Advanced Security)

3. **Collaborators**
   - Review who has write access
   - Use teams for organization

## Questions?

If you're unsure whether something is safe to commit:
1. Check this SECURITY.md file
2. Review `.gitignore`
3. When in doubt, leave it out!

---

**Remember:** It's easier to add a file later than to remove it from git history.
