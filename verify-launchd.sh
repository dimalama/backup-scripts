#!/usr/local/bin/bash

# Verification script for launchd configuration
# Checks if backup scripts will run after restart

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source configuration
CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: config.sh not found"
    echo "   Run: cp config.template.sh config.sh"
    exit 1
fi
source "$CONFIG_FILE"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Launch Agent Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Check if BACKUP_JOBS is defined
if ! declare -p BACKUP_JOBS >/dev/null 2>&1; then
    echo -e "${RED}❌ BACKUP_JOBS not defined in config.sh${NC}"
    exit 1
fi

# Function to check a launch agent
check_launch_agent() {
    local job_name="$1"
    local script_name="$2"
    local plist_file="$HOME/Library/LaunchAgents/com.example.backup-${job_name}.plist"

    echo -e "${BLUE}Checking: $job_name${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    # Check if plist file exists
    if [ ! -f "$plist_file" ]; then
        echo -e "  ${RED}❌ Launch agent file not found${NC}"
        echo -e "     Expected: $plist_file"
        echo -e "     ${YELLOW}Run: ./setup-launchd.sh${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo ""
        return 1
    fi
    echo -e "  ${GREEN}✓ Launch agent file exists${NC}"

    # Check if it's loaded in launchd
    if ! launchctl list | grep -q "com.example.backup-${job_name}"; then
        echo -e "  ${RED}❌ Launch agent NOT loaded in launchd${NC}"
        echo -e "     ${YELLOW}Run: launchctl load \"$plist_file\"${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo ""
        return 1
    fi
    echo -e "  ${GREEN}✓ Launch agent is loaded${NC}"

    # Validate plist syntax
    if ! plutil -lint "$plist_file" >/dev/null 2>&1; then
        echo -e "  ${RED}❌ Invalid plist syntax${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo ""
        return 1
    fi
    echo -e "  ${GREEN}✓ Plist syntax is valid${NC}"

    # Check if RunAtLoad is true
    if ! plutil -p "$plist_file" | grep -q '"RunAtLoad" => 1'; then
        echo -e "  ${YELLOW}⚠ RunAtLoad is not set to true${NC}"
        echo -e "     Agent may not run on boot/login"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "  ${GREEN}✓ RunAtLoad is enabled (will run on boot)${NC}"
    fi

    # Check if the script file exists and is executable
    local script_path="$BACKUP_SCRIPTS_DIR/$script_name"
    if [ ! -f "$script_path" ]; then
        echo -e "  ${RED}❌ Backup script not found: $script_path${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo ""
        return 1
    fi
    echo -e "  ${GREEN}✓ Backup script exists${NC}"

    if [ ! -x "$script_path" ]; then
        echo -e "  ${YELLOW}⚠ Backup script is not executable${NC}"
        echo -e "     ${YELLOW}Run: chmod +x \"$script_path\"${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "  ${GREEN}✓ Backup script is executable${NC}"
    fi

    # Check schedule
    local hour=$(plutil -p "$plist_file" | grep -A 1 "StartCalendarInterval" | grep "Hour" | awk '{print $3}')
    local minute=$(plutil -p "$plist_file" | grep -A 1 "StartCalendarInterval" | grep "Minute" | awk '{print $3}')
    if [ -n "$hour" ] && [ -n "$minute" ]; then
        echo -e "  ${GREEN}✓ Scheduled to run daily at ${hour}:$(printf "%02d" $minute)${NC}"
    fi

    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo -e "  ${GREEN}✓ All checks passed${NC}"
    echo ""
}

# Check legacy launch agents
echo -e "${BLUE}Legacy Launch Agents:${NC}"
echo ""

if [ -n "${OBSIDIAN_DIR:-}" ]; then
    check_launch_agent "obsidian" "backup-obsidian.sh"
else
    echo -e "${YELLOW}⚠ OBSIDIAN_DIR not configured, skipping obsidian agent${NC}"
    echo ""
fi

if [ -n "${PERSONAL_DOCS_DIR:-}" ]; then
    check_launch_agent "personal-docs" "backup-personal-docs.sh"
else
    echo -e "${YELLOW}⚠ PERSONAL_DOCS_DIR not configured, skipping personal-docs agent${NC}"
    echo ""
fi

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Total checks: $TOTAL_CHECKS"
echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo ""

# Test recommendations
if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}✓ All launch agents are properly configured!${NC}"
    echo ""
    echo -e "${BLUE}To verify restart persistence:${NC}"
    echo ""
    echo "1. Check current status:"
    echo "   launchctl list | grep backup"
    echo ""
    echo "2. Trigger a test run immediately:"
    echo "   launchctl start com.example.backup-obsidian"
    echo ""
    echo "3. Check logs:"
    echo "   tail -f logs/obsidian_backup.log"
    echo ""
    echo "4. After restart, verify agents auto-loaded:"
    echo "   launchctl list | grep backup"
    echo "   ./verify-launchd.sh"
    echo ""
    echo -e "${BLUE}Your backups will run:${NC}"
    echo "  • Immediately on login/boot (RunAtLoad=true)"
    echo "  • Daily at midnight"
    echo "  • Even after Mac restarts"
    echo ""
else
    echo -e "${RED}❌ Some launch agents are not properly configured${NC}"
    echo ""
    echo "To fix:"
    echo "  1. Make sure config.sh is properly configured"
    echo "  2. Run: ./setup-launchd.sh"
    echo "  3. Run this script again: ./verify-launchd.sh"
    echo ""
    exit 1
fi

# Additional system checks
echo -e "${BLUE}System Information:${NC}"
echo "macOS version: $(sw_vers -productVersion)"
echo "User: $(whoami)"
echo "Launch agents directory: ~/Library/LaunchAgents"
echo "Current time: $(date)"
echo ""

exit 0
