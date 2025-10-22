#!/bin/bash

##############################################################################
# Wasteland 3 Japanese Translation - Lock File Cleanup Utility
#
# Purpose: Remove stale lock file from retranslation automation
#
# Usage:
#   ./automation/unlock-retranslation.sh [--force]
#
# Options:
#   --force    Force removal even if process appears to be running
#
# Use cases:
# - Script terminated with kill -9 (SIGKILL)
# - System crash or unexpected termination
# - Stale lock preventing new automation run
##############################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOCK_FILE="$SCRIPT_DIR/.retranslation.lock"
FORCE_MODE=false

# Parse arguments
if [[ "${1:-}" == "--force" ]]; then
    FORCE_MODE=true
fi

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "Retranslation Lock Cleanup Utility"
echo "========================================"
echo ""

# Check if lock file exists
if [[ ! -f "$LOCK_FILE" ]]; then
    echo -e "${GREEN}✓${NC} No lock file found - system is not locked"
    echo "Lock file: $LOCK_FILE"
    exit 0
fi

# Read PID from lock file
LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")
echo "Lock file found: $LOCK_FILE"
echo "Locked by PID: $LOCK_PID"
echo ""

# Check if process is still running
if [[ "$LOCK_PID" != "unknown" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
    # Process is running
    PROCESS_CMD=$(ps -p "$LOCK_PID" -o cmd= 2>/dev/null || echo "unknown")

    echo -e "${YELLOW}⚠${NC}  Process $LOCK_PID is still running:"
    echo "   Command: $PROCESS_CMD"
    echo ""

    if [[ "$FORCE_MODE" == true ]]; then
        echo -e "${RED}⚠${NC}  Force mode enabled - removing lock anyway"
        echo ""
        read -p "Are you sure? This may cause conflicts! (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
            rm -f "$LOCK_FILE"
            echo -e "${GREEN}✓${NC} Lock file forcefully removed"
            echo ""
            echo -e "${RED}WARNING:${NC} If process $LOCK_PID is still running, it may"
            echo "         recreate the lock or cause conflicts."
            echo "         Consider terminating it with: kill $LOCK_PID"
        else
            echo "Operation cancelled"
            exit 1
        fi
    else
        echo "Options:"
        echo "  1. Wait for process to finish naturally"
        echo "  2. Terminate process: kill $LOCK_PID"
        echo "  3. Force remove lock: ./automation/unlock-retranslation.sh --force"
        echo ""
        echo -e "${RED}Recommendation:${NC} Terminate the process first, then run this script"
        exit 1
    fi
else
    # Process not running - safe to remove
    echo -e "${YELLOW}⚠${NC}  Lock file is stale (process $LOCK_PID not running)"
    rm -f "$LOCK_FILE"
    echo -e "${GREEN}✓${NC} Stale lock file removed"
fi

echo ""
echo "========================================"
echo "You can now run the automation script:"
echo "  ./automation/auto-retranslate.sh"
echo "========================================"
