#!/bin/bash

# Backup Health Check Script
# Verifies that all backup jobs are configured correctly and up-to-date

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source configuration
CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.sh not found. Please copy config.template.sh to config.sh and configure it."
    exit 1
fi
source "$CONFIG_FILE"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_JOBS=0
HEALTHY_JOBS=0
WARNING_JOBS=0
ERROR_JOBS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Backup Scripts Health Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if BACKUP_JOBS is defined
if ! declare -p BACKUP_JOBS >/dev/null 2>&1; then
    echo -e "${RED}ERROR: BACKUP_JOBS not defined in config.sh${NC}"
    exit 1
fi

# Function to check a single backup job
check_backup_job() {
    local job_name="$1"
    local backup_dir="$2"
    local status="HEALTHY"
    local messages=()

    echo -e "${BLUE}Checking: $job_name${NC}"
    echo "  Directory: $backup_dir"

    # Check if directory exists
    if [ ! -d "$backup_dir" ]; then
        echo -e "  ${RED}✗ Directory does not exist${NC}"
        messages+=("Directory not found")
        status="ERROR"
    else
        echo -e "  ${GREEN}✓ Directory exists${NC}"

        # Check if it's a git repository
        if ! git -C "$backup_dir" rev-parse --git-dir >/dev/null 2>&1; then
            echo -e "  ${RED}✗ Not a git repository${NC}"
            messages+=("Not a git repository")
            status="ERROR"
        else
            echo -e "  ${GREEN}✓ Git repository${NC}"

            # Show current branch
            local current_branch=$(git -C "$backup_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
            echo "  Current branch: $current_branch"

            # Check if there's a remote configured
            if ! git -C "$backup_dir" remote get-url origin >/dev/null 2>&1; then
                echo -e "  ${YELLOW}⚠ No remote 'origin' configured${NC}"
                messages+=("No remote configured")
                status="WARNING"
            else
                local remote_url=$(git -C "$backup_dir" remote get-url origin)
                echo -e "  ${GREEN}✓ Remote configured: $remote_url${NC}"

                # Check if there are uncommitted changes
                if ! git -C "$backup_dir" diff-index --quiet HEAD -- 2>/dev/null; then
                    echo -e "  ${YELLOW}⚠ Uncommitted changes detected${NC}"
                    messages+=("Uncommitted changes")
                    if [ "$status" = "HEALTHY" ]; then
                        status="WARNING"
                    fi
                else
                    echo -e "  ${GREEN}✓ No uncommitted changes${NC}"
                fi

                # Check if local is ahead of remote
                git -C "$backup_dir" fetch origin 2>/dev/null || true
                local local_commit=$(git -C "$backup_dir" rev-parse HEAD 2>/dev/null || echo "")
                local remote_commit=$(git -C "$backup_dir" rev-parse origin/main 2>/dev/null || echo "")

                if [ -n "$local_commit" ] && [ -n "$remote_commit" ]; then
                    if [ "$local_commit" != "$remote_commit" ]; then
                        local ahead=$(git -C "$backup_dir" rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
                        local behind=$(git -C "$backup_dir" rev-list --count HEAD..origin/main 2>/dev/null || echo 0)

                        if [ "$ahead" -gt 0 ]; then
                            echo -e "  ${YELLOW}⚠ Local is $ahead commit(s) ahead of remote${NC}"
                            messages+=("Local ahead of remote")
                            if [ "$status" = "HEALTHY" ]; then
                                status="WARNING"
                            fi
                        fi

                        if [ "$behind" -gt 0 ]; then
                            echo -e "  ${YELLOW}⚠ Local is $behind commit(s) behind remote${NC}"
                            messages+=("Local behind remote")
                            if [ "$status" = "HEALTHY" ]; then
                                status="WARNING"
                            fi
                        fi
                    else
                        echo -e "  ${GREEN}✓ Local and remote are in sync${NC}"
                    fi
                fi

                # Check last commit time
                local last_commit_time=$(git -C "$backup_dir" log -1 --format=%ct 2>/dev/null || echo 0)
                local current_time=$(date +%s)
                local days_since_commit=$(( (current_time - last_commit_time) / 86400 ))

                if [ "$last_commit_time" -gt 0 ]; then
                    echo "  Last commit: $(date -r "$last_commit_time" '+%Y-%m-%d %H:%M:%S') ($days_since_commit days ago)"

                    if [ "$days_since_commit" -gt 30 ]; then
                        echo -e "  ${YELLOW}⚠ No commits in the last 30 days${NC}"
                        messages+=("No recent commits")
                        if [ "$status" = "HEALTHY" ]; then
                            status="WARNING"
                        fi
                    fi
                fi
            fi
        fi
    fi

    # Check log file
    local log_file="$SCRIPT_DIR/logs/${job_name}_backup.log"
    if [ -f "$log_file" ]; then
        echo -e "  ${GREEN}✓ Log file exists${NC}"

        # Check for recent errors in log
        if grep -q "ERROR" "$log_file" 2>/dev/null; then
            local error_count=$(grep -c "ERROR" "$log_file" || echo 0)
            echo -e "  ${YELLOW}⚠ Found $error_count error(s) in log file${NC}"
            if [ "$status" = "HEALTHY" ]; then
                status="WARNING"
            fi
        fi
    else
        echo -e "  ${YELLOW}⚠ Log file not found${NC}"
    fi

    # Print summary for this job
    echo ""
    case "$status" in
        HEALTHY)
            echo -e "  Status: ${GREEN}✓ HEALTHY${NC}"
            HEALTHY_JOBS=$((HEALTHY_JOBS + 1))
            ;;
        WARNING)
            echo -e "  Status: ${YELLOW}⚠ WARNING${NC}"
            echo -e "  Issues: ${messages[*]}${NC}"
            WARNING_JOBS=$((WARNING_JOBS + 1))
            ;;
        ERROR)
            echo -e "  Status: ${RED}✗ ERROR${NC}"
            echo -e "  Issues: ${messages[*]}${NC}"
            ERROR_JOBS=$((ERROR_JOBS + 1))
            ;;
    esac

    echo ""
}

# Check all backup jobs
for job_name in "${!BACKUP_JOBS[@]}"; do
    TOTAL_JOBS=$((TOTAL_JOBS + 1))
    check_backup_job "$job_name" "${BACKUP_JOBS[$job_name]}"
done

# Print overall summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Total jobs: $TOTAL_JOBS"
echo -e "${GREEN}Healthy: $HEALTHY_JOBS${NC}"
echo -e "${YELLOW}Warnings: $WARNING_JOBS${NC}"
echo -e "${RED}Errors: $ERROR_JOBS${NC}"
echo ""

# Check launchd agents (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${BLUE}Launch Agents Status:${NC}"
    for job_name in "${!BACKUP_JOBS[@]}"; do
        plist_file="$HOME/Library/LaunchAgents/com.example.backup-${job_name}.plist"
        if [ -f "$plist_file" ]; then
            if launchctl list | grep -q "com.example.backup-${job_name}"; then
                echo -e "  ${GREEN}✓ com.example.backup-${job_name} is loaded${NC}"
            else
                echo -e "  ${YELLOW}⚠ com.example.backup-${job_name} is not loaded${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠ Launch agent not found for ${job_name}${NC}"
        fi
    done
    echo ""
fi

# Exit with appropriate code
if [ $ERROR_JOBS -gt 0 ]; then
    exit 2
elif [ $WARNING_JOBS -gt 0 ]; then
    exit 1
else
    echo -e "${GREEN}All backup jobs are healthy!${NC}"
    exit 0
fi
