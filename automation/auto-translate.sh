#!/bin/bash
# Wasteland 3 Japanese Translation - Automated Translation Script (Bash version)
# This script runs Claude Code in a loop, automatically restarting sessions
# when memory usage gets too high or after completing a batch of entries.

set -e

# Configuration
MAX_MEMORY_MB=7000
ENTRIES_PER_SESSION=2500
MAX_SESSIONS=100
WORKING_DIR="/home/user/project_claude/game_wasteland/wasteland3-vanilla-langpack-japanese"
LOG_FILE="$WORKING_DIR/automation/translation-automation.log"
SESSION_COUNT=0
TOTAL_ENTRIES=0

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

# Read translation progress
get_progress_entries() {
    local progress_file="$WORKING_DIR/translation/.translation_progress.json"
    if [ -f "$progress_file" ]; then
        jq -r '.total_entries_completed // 0' "$progress_file"
    else
        echo 0
    fi
}

# Update translation progress
update_progress() {
    local session_num="$1"
    local progress_file="$WORKING_DIR/translation/.translation_progress.json"
    if [ -f "$progress_file" ]; then
        local temp_file=$(mktemp)
        jq --arg session "$session_num" --arg timestamp "$(date -Iseconds)" \
           '.session_number = ($session | tonumber) | .last_updated = $timestamp' \
           "$progress_file" > "$temp_file"
        mv "$temp_file" "$progress_file"
    fi
}

# Main automation loop
log "INFO" "=== Wasteland 3 Translation Automation Started ==="
log "INFO" "Max Memory: ${MAX_MEMORY_MB}MB, Entries/Session: $ENTRIES_PER_SESSION, Max Sessions: $MAX_SESSIONS"
log "INFO" "Working Directory: $WORKING_DIR"

cd "$WORKING_DIR"

while [ $SESSION_COUNT -lt $MAX_SESSIONS ]; do
    SESSION_COUNT=$((SESSION_COUNT + 1))
    log "SESSION" "=== Starting Session #$SESSION_COUNT ==="

    # Clean up any existing Claude processes
    cleanup_claude

    # Get current progress
    START_ENTRIES=$(get_progress_entries)
    log "INFO" "Current progress: $START_ENTRIES entries completed"

    # Prepare command for Claude Code
    COMMAND_FILE="$WORKING_DIR/automation/.current_command.txt"
    cat > "$COMMAND_FILE" << EOF
translation/.translation_progress.json を読み込んで、CLAUDE.mdのルールに従って翻訳作業を継続してください。

目標: 約${ENTRIES_PER_SESSION}エントリを翻訳して、コミット・プッシュしてから進捗を報告してください。

重要な指示:
1. wasteland3-translatorサブエージェントを使用
2. 100-200行チャンクで処理（メモリ管理）
3. 各主要セクション完了後にコミット
4. ${ENTRIES_PER_SESSION}エントリ到達後は作業を終了して報告

処理完了後、以下の形式で報告してください:
- 翻訳完了エントリ数: XXXX
- 最新コミットハッシュ: XXXXXXX
- 次のセクション: section_name

この報告後、セッションを終了してください。
EOF

    log "INFO" "Starting Claude Code with automated command..."

    # Run Claude Code with timeout and memory monitoring
    OUTPUT_FILE="$WORKING_DIR/automation/.session_${SESSION_COUNT}_output.log"

    # Start Claude Code in background with input redirection
    timeout 3600 bash -c "cat '$COMMAND_FILE' | claude" > "$OUTPUT_FILE" 2>&1 &
    CLAUDE_PID=$!

    # Monitor memory usage
    MONITOR_INTERVAL=30
    while kill -0 $CLAUDE_PID 2>/dev/null; do
        sleep $MONITOR_INTERVAL

        MEMORY=$(get_claude_memory)
        log "INFO" "Memory usage: ${MEMORY}MB"

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

    # Update progress
    END_ENTRIES=$(get_progress_entries)
    ENTRIES_THIS_SESSION=$((END_ENTRIES - START_ENTRIES))
    TOTAL_ENTRIES=$((TOTAL_ENTRIES + ENTRIES_THIS_SESSION))

    log "INFO" "Session #$SESSION_COUNT completed: $ENTRIES_THIS_SESSION entries translated"
    log "INFO" "Cumulative total: $END_ENTRIES entries"

    # Update session number in progress file
    update_progress $SESSION_COUNT

    # Check if translation is complete
    if grep -q "complete\|finished\|done" "$WORKING_DIR/translation/.translation_progress.json" 2>/dev/null; then
        log "SUCCESS" "Translation appears to be complete!"
        break
    fi

    # Brief pause before next session
    log "INFO" "Waiting 10 seconds before starting next session..."
    sleep 10
done

log "SUCCESS" "=== Translation Automation Completed ==="
log "INFO" "Total Sessions: $SESSION_COUNT"
log "INFO" "Total Entries Translated: $TOTAL_ENTRIES"
log "INFO" "Check translation/.translation_progress.json for final status"

# Final cleanup
cleanup_claude
