#!/bin/bash
# Wasteland 3 Japanese Translation - Improved Automated Translation Script
# VERSION 2.0 - After heap out of memory error on 2025-10-22
#
# Key improvements:
# - Reduced memory threshold (6GB instead of 7GB)
# - Reduced entries per session (1000 instead of 2500)
# - More frequent memory monitoring (15s instead of 30s)
# - Dynamic chunk size based on memory usage

set -e

# Configuration - IMPROVED VALUES
MAX_MEMORY_MB=6000          # Reduced from 7000MB (trigger restart earlier)
WARNING_MEMORY_MB=4000      # New: Warning level for aggressive memory management
ENTRIES_PER_SESSION=1000    # Reduced from 2500 (smaller batches = safer)
MAX_SESSIONS=200            # Increased to handle more sessions with smaller batches
MONITOR_INTERVAL=15         # Reduced from 30s (catch memory spikes faster)

# Get the directory where this script is located, then get the parent directory (repository root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKING_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$WORKING_DIR/automation/translation-automation.log"
SESSION_COUNT=0
TOTAL_ENTRIES=0
ZERO_ENTRY_COUNT=0

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
log "INFO" "=== Wasteland 3 Translation Automation Started (v2.0 - Improved Memory Management) ==="
log "INFO" "Max Memory: ${MAX_MEMORY_MB}MB (Warning: ${WARNING_MEMORY_MB}MB)"
log "INFO" "Entries/Session: $ENTRIES_PER_SESSION (reduced for safety)"
log "INFO" "Monitor Interval: ${MONITOR_INTERVAL}s (faster detection)"
log "INFO" "Max Sessions: $MAX_SESSIONS"
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

    # Determine chunk size based on previous session's memory usage
    # Start conservative after OOM error
    CHUNK_SIZE=50
    COMMIT_FREQ=100

    log "INFO" "Using CONSERVATIVE settings: ${CHUNK_SIZE} lines/chunk, commit every ${COMMIT_FREQ} entries"

    # Prepare command for Claude Code
    COMMAND_FILE="$WORKING_DIR/automation/.current_command.txt"
    cat > "$COMMAND_FILE" << EOF
translation/.translation_progress.json を読み込んで、CLAUDE.mdのルールに従って翻訳作業を継続してください。

⚠️ **自動実行モード - STRICT MEMORY MANAGEMENT**:
- **サブエージェントは使用しない** - メインセッションで直接翻訳
- **厳格なメモリ管理** - heap out of memory エラーの再発を防止
- **小さいチャンクサイズ**: ${CHUNK_SIZE}行/チャンク (以前のエラーを受けて削減)
- **頻繁なコミット**: ${COMMIT_FREQ}エントリごと (メモリ解放のため)
- 全ての権限リクエストは自動承認
- ユーザーへの質問や確認なしで作業を進行

目標: 約${ENTRIES_PER_SESSION}エントリを翻訳して、コミット・プッシュしてから進捗を報告してください。

重要な指示:
1. **メインセッションで直接翻訳** (サブエージェントは使わない)
2. **${CHUNK_SIZE}行チャンクで処理** (NEVER exceed ${CHUNK_SIZE} lines per Read/Edit)
3. **${COMMIT_FREQ}エントリまたは各セクション完了時にコミット** (少ない方を選択)
4. 各チャンク処理後に変数をクリア (メモリ解放)
5. ${ENTRIES_PER_SESSION}エントリ到達後は作業を終了して報告
6. **質問や確認を求めずに自動実行**
7. nouns_glossary.json を参照して一貫性を保つ

メモリ管理 (CRITICAL):
- 各Read/Edit操作は最大${CHUNK_SIZE}行まで (厳格に遵守)
- ${COMMIT_FREQ}エントリまたは各セクション完了時に必ずコミット
- 大きなファイルは必ず複数回のRead/Edit操作に分割
- git diff は常に head -100 で制限
- 逐次処理のみ（並列処理は禁止）

処理完了後、以下の形式で報告してください:
- 翻訳完了エントリ数: XXXX
- 最新コミットハッシュ: XXXXXXX
- 次のセクション: section_name
- メモリ使用状況: OK/WARNING

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

    # Monitor memory usage with enhanced logging
    MEMORY_WARNINGS=0
    while kill -0 $CLAUDE_PID 2>/dev/null; do
        sleep $MONITOR_INTERVAL

        MEMORY=$(get_claude_memory)

        if [ $MEMORY -gt $WARNING_MEMORY_MB ] && [ $MEMORY -le $MAX_MEMORY_MB ]; then
            log "WARN" "Memory warning: ${MEMORY}MB (>${WARNING_MEMORY_MB}MB) - approaching limit"
            MEMORY_WARNINGS=$((MEMORY_WARNINGS + 1))
            # If we get 3 warnings in a row, proactively restart
            if [ $MEMORY_WARNINGS -ge 3 ]; then
                log "WARN" "Multiple memory warnings detected, proactively terminating session"
                kill -TERM $CLAUDE_PID 2>/dev/null || true
                sleep 5
                kill -KILL $CLAUDE_PID 2>/dev/null || true
                break
            fi
        elif [ $MEMORY -le $WARNING_MEMORY_MB ]; then
            # Reset warning count if memory drops
            MEMORY_WARNINGS=0
            log "INFO" "Memory usage: ${MEMORY}MB (OK)"
        fi

        if [ $MEMORY -gt $MAX_MEMORY_MB ]; then
            log "ERROR" "Memory threshold exceeded (${MEMORY}MB > ${MAX_MEMORY_MB}MB), terminating session"
            kill -TERM $CLAUDE_PID 2>/dev/null || true
            sleep 5
            kill -KILL $CLAUDE_PID 2>/dev/null || true
            break
        fi
    done

    # Wait for Claude Code to finish
    wait $CLAUDE_PID 2>/dev/null || true

    log "INFO" "Claude Code session completed"

    # Check for errors in output
    if grep -qi "out of memory\|heap\|fatal error" "$OUTPUT_FILE"; then
        log "ERROR" "Memory error detected in session output!"
        log "ERROR" "Reducing chunk size for next session"
        # Could implement dynamic chunk size reduction here
    fi

    # Update progress
    END_ENTRIES=$(get_progress_entries)
    ENTRIES_THIS_SESSION=$((END_ENTRIES - START_ENTRIES))
    TOTAL_ENTRIES=$((TOTAL_ENTRIES + ENTRIES_THIS_SESSION))

    log "INFO" "Session #$SESSION_COUNT completed: $ENTRIES_THIS_SESSION entries translated"
    log "INFO" "Cumulative total: $END_ENTRIES entries"

    # Backup progress file
    cp "$WORKING_DIR/translation/.translation_progress.json" \
       "$WORKING_DIR/translation/.translation_progress.backup.json" 2>/dev/null || true

    # Update session number in progress file
    update_progress $SESSION_COUNT

    # Check if translation is complete (status field must be "complete")
    if grep -q '"status"[[:space:]]*:[[:space:]]*"complete"' "$WORKING_DIR/translation/.translation_progress.json" 2>/dev/null; then
        log "SUCCESS" "Translation appears to be complete!"
        break
    fi

    # Safety check: if 3 consecutive sessions with 0 entries, likely stuck or complete
    if [ $ENTRIES_THIS_SESSION -eq 0 ]; then
        ZERO_ENTRY_COUNT=$((ZERO_ENTRY_COUNT + 1))
        if [ $ZERO_ENTRY_COUNT -ge 3 ]; then
            log "WARN" "3 consecutive sessions with 0 entries translated - stopping"
            log "WARN" "Please check .session_*_output.log files for errors"
            break
        fi
    else
        ZERO_ENTRY_COUNT=0
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
