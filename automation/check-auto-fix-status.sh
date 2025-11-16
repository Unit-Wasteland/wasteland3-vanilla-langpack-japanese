#!/bin/bash
##############################################################################
# Check Auto-Fix Untranslated Status
#
# Purpose: Check the status of background auto-fix process
#
# Usage:
#   ./automation/check-auto-fix-status.sh
#
##############################################################################

echo "========================================"
echo "Auto-Fix Untranslated - Status Check"
echo "========================================"
echo ""

# Check if process is running
echo "=== Process Status ==="
if ps aux | grep -q "[a]uto-fix-untranslated.sh"; then
    PID=$(ps aux | grep "[a]uto-fix-untranslated.sh" | awk '{print $2}')
    UPTIME=$(ps -o etime= -p $PID 2>/dev/null | tr -d ' ')
    echo "✅ Status: RUNNING"
    echo "   PID: $PID"
    echo "   Uptime: $UPTIME"
else
    echo "⛔ Status: NOT RUNNING"
    echo ""
    echo "To start:"
    echo "  PROTECTED_CLAUDE_PID=\$(pgrep claude | head -1) nohup bash automation/auto-fix-untranslated.sh > automation/.auto-fix-bg.log 2>&1 &"
fi
echo ""

# Check untranslated count
echo "=== Progress ==="
if [ -f "automation/.untranslated_lines.txt" ]; then
    UNTRANSLATED_COUNT=$(wc -l < automation/.untranslated_lines.txt)
    TOTAL_ORIGINAL=20952
    FIXED=$((TOTAL_ORIGINAL - UNTRANSLATED_COUNT))
    PERCENT=$(awk "BEGIN {printf \"%.1f\", ($FIXED / $TOTAL_ORIGINAL) * 100}")

    echo "Total original: $TOTAL_ORIGINAL entries"
    echo "Fixed so far:   $FIXED entries"
    echo "Remaining:      $UNTRANSLATED_COUNT entries"
    echo "Progress:       $PERCENT%"
else
    echo "⚠ Untranslated list not found"
    echo "Generate with: bash automation/generate-untranslated-list.sh"
fi
echo ""

# Check recent activity
echo "=== Recent Activity (last 10 log lines) ==="
if [ -f "automation/untranslated-fix-automation.log" ]; then
    tail -10 automation/untranslated-fix-automation.log
else
    echo "⚠ Log file not found"
fi
echo ""

# Show log file sizes
echo "=== Log Files ==="
if [ -f "automation/untranslated-fix-automation.log" ]; then
    MAIN_LOG_SIZE=$(du -h automation/untranslated-fix-automation.log | awk '{print $1}')
    echo "Main log:       $MAIN_LOG_SIZE (automation/untranslated-fix-automation.log)"
fi
if [ -f "automation/.auto-fix-bg.log" ]; then
    BG_LOG_SIZE=$(du -h automation/.auto-fix-bg.log | awk '{print $1}')
    echo "Background log: $BG_LOG_SIZE (automation/.auto-fix-bg.log)"
fi
echo ""

# Show monitoring commands
echo "=== Monitoring Commands ==="
echo "Real-time log:"
echo "  tail -f automation/untranslated-fix-automation.log"
echo ""
echo "Background log:"
echo "  tail -f automation/.auto-fix-bg.log"
echo ""
echo "Stop process:"
if ps aux | grep -q "[a]uto-fix-untranslated.sh"; then
    PID=$(ps aux | grep "[a]uto-fix-untranslated.sh" | awk '{print $2}')
    echo "  kill $PID"
fi
echo ""

echo "========================================"
