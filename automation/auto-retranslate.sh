#!/bin/bash
##############################################################################
# Wasteland 3 Japanese Translation - Automated Retranslation Script
#
# Purpose: Fully automated retranslation with structure protection
#
# Architecture: Based on successful auto-translate.sh pattern
# - Large chunks (150-200 lines) to minimize Read/Edit operations
# - Simplified commands to reduce conversation history size
# - High entries-per-session (500) for efficiency
# - Appropriate memory thresholds for 6GB RAM environment
#
# Root Cause Fix:
# Previous version (20-line chunks, 5 entries/session) caused:
# - ~90 Read/Edit operations per session
# - Massive conversation history accumulation
# - Memory explosion during session-end JSON.stringify (1055MB→2305MB in 30s)
#
# New version (150-200 line chunks, 500 entries/session):
# - ~10-15 Read/Edit operations per session (85% reduction)
# - Small conversation history
# - No memory spikes during session end
#
# Usage:
#   ./automation/auto-retranslate.sh         # Start automated retranslation
#   ./automation/auto-retranslate.sh --unlock # Remove lock file and exit
#
##############################################################################

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_FILE="$SCRIPT_DIR/.retranslation.lock"

# Parse command line arguments FIRST (before set -e)
if [[ "${1:-}" == "--unlock" ]]; then
    echo "========================================"
    echo "Unlocking retranslation automation"
    echo "========================================"

    if [[ ! -f "$LOCK_FILE" ]]; then
        echo "✓ No lock file found - system is already unlocked"
        exit 0
    fi

    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")
    echo "Lock file: $LOCK_FILE"
    echo "Locked by PID: $LOCK_PID"

    # Check if process is still running
    if [[ "$LOCK_PID" != "unknown" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
        echo "⚠ WARNING: Process $LOCK_PID is still running!"
        echo "  Consider terminating it first: kill $LOCK_PID"
        exit 1
    else
        rm -f "$LOCK_FILE"
        echo "✓ Stale lock file removed"
        echo ""
        echo "You can now run: ./automation/auto-retranslate.sh"
        exit 0
    fi
fi

set -e

# Configuration
MAX_MEMORY_MB=5000          # 6GB physical RAM - 1GB margin
ENTRIES_PER_SESSION=500     # 500 entries per session (100x improvement from 5)
MAX_SESSIONS=150            # Max 150 sessions (should complete in ~150 sessions)
MONITOR_INTERVAL=30         # Check memory every 30 seconds

# Working directory (SCRIPT_DIR already defined above for --unlock handling)
WORKING_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$WORKING_DIR/automation/retranslation-automation.log"
SESSION_COUNT=0
TOTAL_ENTRIES=0
ZERO_ENTRY_COUNT=0

# Push tracking
CONSECUTIVE_PUSH_FAILURES=0
readonly MAX_PUSH_FAILURES=3

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Get Claude Code process memory usage (in MB)
get_claude_memory() {
    local memory=$(ps aux | grep "[c]laude" | awk '{sum += $6} END {print sum}')
    if [ -n "$memory" ] && [ "$memory" != "" ] && [ "$memory" != "0" ]; then
        echo $((memory / 1024))
    else
        echo 0
    fi
}

# Kill any existing Claude Code processes
cleanup_claude() {
    pkill -9 claude 2>/dev/null || true
    sleep 2
}

# Lock file management
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")

        # Check if the process is still running
        if [[ "$lock_pid" != "unknown" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            log "ERROR" "Another retranslation session is already running (PID: $lock_pid)"
            exit 1
        else
            log "INFO" "Removing stale lock file (PID: $lock_pid no longer running)"
            rm -f "$LOCK_FILE"
        fi
    fi

    echo "$$" > "$LOCK_FILE"
    log "INFO" "Lock acquired (PID: $$)"
}

release_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
        log "INFO" "Lock released"
    fi
}

# Ensure lock is released on exit
trap release_lock EXIT INT TERM

# Read retranslation progress
get_progress_entries() {
    local progress_file="$WORKING_DIR/translation/.retranslation_progress.json"
    if [ -f "$progress_file" ]; then
        jq -r '.total_entries_completed // 0' "$progress_file"
    else
        echo 0
    fi
}

# Check if retranslation is complete
is_retranslation_complete() {
    local progress_file="$WORKING_DIR/translation/.retranslation_progress.json"
    if [ -f "$progress_file" ]; then
        local status_base status_dlc1 status_dlc2
        status_base=$(jq -r '.files.base_game.status' "$progress_file")
        status_dlc1=$(jq -r '.files.dlc1.status' "$progress_file")
        status_dlc2=$(jq -r '.files.dlc2.status' "$progress_file")

        if [[ "$status_base" == "completed" ]] && \
           [[ "$status_dlc1" == "completed" ]] && \
           [[ "$status_dlc2" == "completed" ]]; then
            return 0  # Complete
        fi
    fi
    return 1  # Not complete
}

# Main automation loop
log "INFO" "========================================="
log "INFO" "Wasteland 3 Retranslation Automation"
log "INFO" "========================================="
log "INFO" "Architecture: Based on successful auto-translate.sh pattern"
log "INFO" "Max Memory: ${MAX_MEMORY_MB}MB, Entries/Session: $ENTRIES_PER_SESSION, Max Sessions: $MAX_SESSIONS"
log "INFO" "Chunk Size: 150-200 lines (large chunks to minimize operations)"
log "INFO" "Working Directory: $WORKING_DIR"
log "INFO" "Start time: $(date)"
log "INFO" ""

# Acquire exclusive lock (prevent duplicate sessions)
acquire_lock

# Check prerequisites
if [ ! -f "$WORKING_DIR/translation/.retranslation_progress.json" ]; then
    log "ERROR" "Progress file not found: translation/.retranslation_progress.json"
    exit 1
fi

cd "$WORKING_DIR"

# Check if already complete
if is_retranslation_complete; then
    log "SUCCESS" "========================================="
    log "SUCCESS" "✅ RETRANSLATION COMPLETE!"
    log "SUCCESS" "========================================="
    log "SUCCESS" "All files have been retranslated successfully."
    log "SUCCESS" "Total entries: $(get_progress_entries)"
    log "SUCCESS" "End time: $(date)"
    exit 0
fi

while [ $SESSION_COUNT -lt $MAX_SESSIONS ]; do
    SESSION_COUNT=$((SESSION_COUNT + 1))
    log "SESSION" "========================================="
    log "SESSION" "Starting Session #$SESSION_COUNT"
    log "SESSION" "========================================="

    # Clean up any existing Claude processes
    cleanup_claude

    # Get current progress
    START_ENTRIES=$(get_progress_entries)
    log "INFO" "Current progress: $START_ENTRIES entries completed"

    # Prepare command for Claude Code (SIMPLIFIED - based on auto-translate.sh)
    COMMAND_FILE="$WORKING_DIR/automation/.current_retranslate_command.txt"
    cat > "$COMMAND_FILE" << EOF
translation/.retranslation_progress.json を読み込んで、translation/RETRANSLATION_WORKFLOW.md に従って翻訳やり直し作業を継続してください。

⚠️ **自動実行モード**:
- メインセッションで直接作業（サブエージェント不使用）
- 全ての権限リクエストは自動承認
- 質問や確認なしで作業を進める

目標: 約${ENTRIES_PER_SESSION}エントリを処理してコミット・プッシュ

重要な指示:
1. **150-200行チャンクで処理**（メモリ効率を最大化、Read/Edit操作を最小化）
2. 500エントリごとにコミット
3. nouns_glossary.json参照
4. 構造保護ルール厳守（CLAUDE.md参照: ""、[]、<>、::action:: 保護）
5. ${ENTRIES_PER_SESSION}エントリ到達後は作業終了して報告

処理完了後、以下の形式で報告:
- 翻訳完了エントリ数: XXXX
- 最新コミットハッシュ: XXXXXXX
- 次のセクション: section_name

この報告後、セッションを終了してください。
EOF

    log "INFO" "Starting Claude Code with automated command..."

    # Run Claude Code with timeout and memory monitoring
    OUTPUT_FILE="$WORKING_DIR/automation/.session_${SESSION_COUNT}_output.log"

    # Start Claude Code in background with input redirection
    # --dangerously-skip-permissions: Bypass all permission checks for automated execution
    # yes: Automatically answer 'y' to any interactive permission prompts
    timeout 3600 bash -c "yes | cat '$COMMAND_FILE' | claude --dangerously-skip-permissions" > "$OUTPUT_FILE" 2>&1 &
    CLAUDE_PID=$!

    log "INFO" "Claude Code session started (PID: $CLAUDE_PID)"

    # Monitor memory usage
    while kill -0 $CLAUDE_PID 2>/dev/null; do
        sleep $MONITOR_INTERVAL

        MEMORY=$(get_claude_memory)
        log "INFO" "Memory usage: ${MEMORY}MB / ${MAX_MEMORY_MB}MB"

        if [ $MEMORY -gt $MAX_MEMORY_MB ]; then
            log "WARN" "Memory threshold exceeded (${MEMORY}MB > ${MAX_MEMORY_MB}MB), terminating session"
            kill -TERM $CLAUDE_PID 2>/dev/null || true
            sleep 5
            kill -KILL $CLAUDE_PID 2>/dev/null || true
            break
        fi
    done

    # Wait for Claude Code to finish
    wait $CLAUDE_PID 2>/dev/null || true

    log "INFO" "Claude Code session completed"

    # Get progress after session
    END_ENTRIES=$(get_progress_entries)
    ENTRIES_THIS_SESSION=$((END_ENTRIES - START_ENTRIES))
    TOTAL_ENTRIES=$((TOTAL_ENTRIES + ENTRIES_THIS_SESSION))

    log "INFO" "Session #$SESSION_COUNT completed: $ENTRIES_THIS_SESSION entries translated"
    log "INFO" "Cumulative total: $END_ENTRIES entries (out of ~71,992)"

    # Check if retranslation is complete
    if is_retranslation_complete; then
        log "SUCCESS" "========================================="
        log "SUCCESS" "✅ RETRANSLATION COMPLETE!"
        log "SUCCESS" "========================================="
        log "SUCCESS" "All files have been retranslated successfully."
        log "SUCCESS" "Total entries: $END_ENTRIES"
        log "SUCCESS" "Total sessions: $SESSION_COUNT"
        log "SUCCESS" "End time: $(date)"
        exit 0
    fi

    # Safety check: if 3 consecutive sessions with 0 entries, likely stuck or complete
    if [ $ENTRIES_THIS_SESSION -eq 0 ]; then
        ZERO_ENTRY_COUNT=$((ZERO_ENTRY_COUNT + 1))
        log "WARN" "Zero entries completed (consecutive: $ZERO_ENTRY_COUNT / 3)"

        if [ $ZERO_ENTRY_COUNT -ge 3 ]; then
            log "ERROR" "3 consecutive sessions with 0 entries translated - stopping"
            log "ERROR" "Please check .session_*_output.log files for errors"
            log "ERROR" "Last session log: $OUTPUT_FILE"
            exit 1
        fi
    else
        ZERO_ENTRY_COUNT=0

        # Push to remote after successful progress
        log "INFO" "Pushing changes to remote repository..."
        if git push origin main >> "$LOG_FILE" 2>&1; then
            log "INFO" "✓ Successfully pushed to remote (commits: $ENTRIES_THIS_SESSION entries)"
            CONSECUTIVE_PUSH_FAILURES=0
        else
            CONSECUTIVE_PUSH_FAILURES=$((CONSECUTIVE_PUSH_FAILURES + 1))
            log "WARN" "⚠ Failed to push to remote (consecutive failures: $CONSECUTIVE_PUSH_FAILURES / $MAX_PUSH_FAILURES)"
            log "WARN" "  Local commits are safe but not backed up to remote"

            if [ $CONSECUTIVE_PUSH_FAILURES -ge $MAX_PUSH_FAILURES ]; then
                log "ERROR" "$MAX_PUSH_FAILURES consecutive push failures detected"
                log "ERROR" "  Please check network connection and git remote configuration"
                exit 1
            fi
        fi
    fi

    # Brief pause before next session
    log "INFO" "Waiting 60 seconds before starting next session..."
    log "INFO" ""
    sleep 60
done

log "SUCCESS" "========================================="
log "SUCCESS" "Translation Automation Completed"
log "SUCCESS" "========================================="
log "SUCCESS" "Total Sessions: $SESSION_COUNT"
log "SUCCESS" "Total Entries Translated: $TOTAL_ENTRIES"
log "SUCCESS" "End time: $(date)"

# Final cleanup
cleanup_claude
