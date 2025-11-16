#!/bin/bash
##############################################################################
# Wasteland 3 Japanese Translation - Automated Untranslated Entry Fixer
#
# Purpose: Automatically detect and fix untranslated entries
#
# Workflow:
# 1. Generate list of untranslated line numbers
# 2. Process entries in batches (sequential, not bulk)
# 3. Each Claude session translates ~20-50 entries using Read+Edit
# 4. Validate after each session
# 5. Repeat until all entries translated
#
# Usage:
#   ./automation/auto-fix-untranslated.sh
#
##############################################################################

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_FILE="$SCRIPT_DIR/.untranslated_fix.lock"

# Configuration
MAX_MEMORY_MB=5000          # 6GB physical RAM - 1GB margin
ENTRIES_PER_SESSION=20      # Process 20 entries per session (conservative for fixes)
MAX_SESSIONS=1050           # Max sessions (20,955 entries ÷ 20)
MONITOR_INTERVAL=30         # Check memory every 30 seconds

# Working directory
WORKING_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$WORKING_DIR/automation/untranslated-fix-automation.log"
UNTRANSLATED_LIST="$WORKING_DIR/automation/.untranslated_lines.txt"
SESSION_COUNT=0
TOTAL_FIXED=0
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

# Kill any existing Claude Code processes (except protected PID)
cleanup_claude() {
    # Get protected PID from environment variable (if set)
    local protected_pid="${PROTECTED_CLAUDE_PID:-}"

    if [ -n "$protected_pid" ]; then
        # Kill all claude processes except the protected one
        ps aux | grep "[c]laude" | awk '{print $2}' | while read pid; do
            if [ "$pid" != "$protected_pid" ]; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        done
    else
        # No protection - kill all
        pkill -9 claude 2>/dev/null || true
    fi
    sleep 2
}

# Lock file management
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")

        if [[ "$lock_pid" != "unknown" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            log "ERROR" "Another untranslated fix session is already running (PID: $lock_pid)"
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

trap release_lock EXIT INT TERM

# Main automation loop
log "INFO" "========================================="
log "INFO" "Untranslated Entry Fixer - Automated"
log "INFO" "========================================="
log "INFO" "Max Memory: ${MAX_MEMORY_MB}MB, Entries/Session: $ENTRIES_PER_SESSION"
log "INFO" "Working Directory: $WORKING_DIR"
log "INFO" "Start time: $(date)"
log "INFO" ""

# Acquire exclusive lock
acquire_lock

# Check if untranslated list exists, if not generate it
if [ ! -f "$UNTRANSLATED_LIST" ]; then
    log "INFO" "Untranslated list not found, generating..."
    bash "$SCRIPT_DIR/generate-untranslated-list.sh"
fi

# Check if list is empty
UNTRANSLATED_COUNT=$(wc -l < "$UNTRANSLATED_LIST" 2>/dev/null || echo "0")
if [ "$UNTRANSLATED_COUNT" -eq 0 ]; then
    log "SUCCESS" "========================================="
    log "SUCCESS" "✅ NO UNTRANSLATED ENTRIES!"
    log "SUCCESS" "========================================="
    log "SUCCESS" "All entries have been translated successfully."
    log "SUCCESS" "End time: $(date)"
    exit 0
fi

log "INFO" "Total untranslated entries to fix: $UNTRANSLATED_COUNT"
log "INFO" ""

cd "$WORKING_DIR"

while [ $SESSION_COUNT -lt $MAX_SESSIONS ]; do
    SESSION_COUNT=$((SESSION_COUNT + 1))
    log "SESSION" "========================================="
    log "SESSION" "Starting Session #$SESSION_COUNT"
    log "SESSION" "========================================="

    # Check if list is empty
    UNTRANSLATED_COUNT=$(wc -l < "$UNTRANSLATED_LIST" 2>/dev/null || echo "0")
    if [ "$UNTRANSLATED_COUNT" -eq 0 ]; then
        log "SUCCESS" "✅ All untranslated entries fixed!"
        break
    fi

    log "INFO" "Remaining untranslated entries: $UNTRANSLATED_COUNT"

    # Clean up any existing Claude processes
    cleanup_claude

    # Get next batch of line numbers (up to ENTRIES_PER_SESSION)
    BATCH_LINES=$(head -n $ENTRIES_PER_SESSION "$UNTRANSLATED_LIST" | tr '\n' ',' | sed 's/,$//')
    BATCH_COUNT=$(head -n $ENTRIES_PER_SESSION "$UNTRANSLATED_LIST" | wc -l)

    log "INFO" "Processing batch of $BATCH_COUNT entries"
    log "INFO" "Line numbers: $BATCH_LINES"

    # Prepare command for Claude Code
    COMMAND_FILE="$WORKING_DIR/automation/.fix_untranslated_command.txt"

    cat > "$COMMAND_FILE" << 'EOF'
🔴 **未翻訳エントリ修正タスク - 自動処理モード**

**処理手順（CLAUDE.md厳守）:**

1. **未翻訳リストの読み込み:**
   - automation/.untranslated_lines.txt を読み込み
   - 最初の20行の行番号を取得

2. **各エントリを順次処理**（一括処理禁止）:
   - 各行番号について、以下を実行:
     a) Read ツールで該当行の前後3-5行を読み込み（コンテキスト把握）
     b) **英語ソースファイルで該当行のクォート形式を確認:**
        - シングルクォート: `string data = " content"` → 日本語も `string data = " 日本語"` にする
        - ダブルダブルクォート: `string data = ""content""` → 日本語も `string data = ""日本語""` にする
     c) 英語ソースと比較して、翻訳が必要か判断:
        - do_not_translate リストに該当 → 英語のまま保持
        - nouns_glossary.json に登録 → 用語集の訳語で翻訳
        - それ以外 → 日本語に翻訳
     d) Edit ツールで該当行のみを修正（周辺行は変更しない）
        - **クォート形式は英語ソースと完全一致させる（必須）**
     e) 修正後、以下の検証を必ず実行:
        - 構造検証: python3 translation/validate_structure_v2.py ... --detailed
        - アクションマーカー検証: grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' ...
        - エラーがあれば即座に修正、再検証

3. **CLAUDE.md 絶対ルール厳守:**
   - ✅ Read + Edit ツールのみ使用
   - ❌ スクリプトによる一括翻訳禁止
   - ❌ 複数行のまとめて処理禁止
   - ✅ 1エントリずつ順次処理

4. **構造保護（CRITICAL）:**
   - "" マーカー保護（Unity形式）
   - ::action:: マーカーは英語のまま保持
   - **[]ブラケットマーカーは絶対に翻訳禁止** - ゲームエンジンが認識する必須構造マーカー
     * 選択肢マーカー: [Attack], [Abandon], [Lie], [Truth], [Kill], [Leave], etc.
     * 技術マーカー: [Global:...], [Switch to...], [Dropset:...], [Reward:...], etc.
     * 例: "[Attack] "行くぞ。"" → OK（[]内は英語のまま）
     * 例: "[攻撃] "行くぞ。"" → ❌ 絶対禁止（ゲームが動作不能になる）
   - Script Node は翻訳禁止

5. **完了後:**
   - 処理したエントリ数を報告
   - git add + git commit
   - セッション終了

⚠️ **重要**: 質問や確認なしで自動実行してください。
EOF

    log "INFO" "Starting Claude Code with automated command..."

    # Run Claude Code with timeout and memory monitoring
    OUTPUT_FILE="$WORKING_DIR/automation/.fix_untranslated_output.log"

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

    wait $CLAUDE_PID 2>/dev/null || true

    log "INFO" "Claude Code session completed"

    # Regenerate untranslated list to see what was fixed
    log "INFO" "Regenerating untranslated list..."
    bash "$SCRIPT_DIR/generate-untranslated-list.sh" > /dev/null 2>&1 || true

    NEW_UNTRANSLATED_COUNT=$(wc -l < "$UNTRANSLATED_LIST" 2>/dev/null || echo "0")
    FIXED_THIS_SESSION=$((UNTRANSLATED_COUNT - NEW_UNTRANSLATED_COUNT))
    TOTAL_FIXED=$((TOTAL_FIXED + FIXED_THIS_SESSION))

    log "INFO" "Session #$SESSION_COUNT completed: $FIXED_THIS_SESSION entries fixed"
    log "INFO" "Remaining untranslated: $NEW_UNTRANSLATED_COUNT"
    log "INFO" "Total fixed: $TOTAL_FIXED"

    # Safety check: if 3 consecutive sessions with 0 fixes, likely stuck
    if [ $FIXED_THIS_SESSION -eq 0 ]; then
        ZERO_ENTRY_COUNT=$((ZERO_ENTRY_COUNT + 1))
        log "WARN" "Zero entries fixed (consecutive: $ZERO_ENTRY_COUNT / 3)"

        if [ $ZERO_ENTRY_COUNT -ge 3 ]; then
            log "ERROR" "3 consecutive sessions with 0 entries fixed - stopping"
            log "ERROR" "Please check output log: $OUTPUT_FILE"
            exit 1
        fi
    else
        ZERO_ENTRY_COUNT=0

        # Validate and push
        log "INFO" "Running validation..."
        TARGET_FILE="$WORKING_DIR/translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"
        SOURCE_FILE="$WORKING_DIR/translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"

        if python3 "$WORKING_DIR/translation/validate_structure_v2.py" \
            "$TARGET_FILE" \
            --source "$SOURCE_FILE" \
            --detailed > /dev/null 2>&1; then
            log "INFO" "✓ Structure validation passed"
        else
            log "WARN" "✗ Structure validation failed - check output"
        fi

        # Push to remote
        log "INFO" "Pushing changes to remote repository..."
        if git push origin main >> "$LOG_FILE" 2>&1; then
            log "INFO" "✓ Successfully pushed to remote"
            CONSECUTIVE_PUSH_FAILURES=0
        else
            CONSECUTIVE_PUSH_FAILURES=$((CONSECUTIVE_PUSH_FAILURES + 1))
            log "WARN" "⚠ Failed to push (consecutive: $CONSECUTIVE_PUSH_FAILURES / $MAX_PUSH_FAILURES)"

            if [ $CONSECUTIVE_PUSH_FAILURES -ge $MAX_PUSH_FAILURES ]; then
                log "ERROR" "$MAX_PUSH_FAILURES consecutive push failures"
                exit 1
            fi
        fi
    fi

    # Check if complete
    if [ $NEW_UNTRANSLATED_COUNT -eq 0 ]; then
        log "SUCCESS" "========================================="
        log "SUCCESS" "✅ ALL UNTRANSLATED ENTRIES FIXED!"
        log "SUCCESS" "========================================="
        log "SUCCESS" "Total fixed: $TOTAL_FIXED"
        log "SUCCESS" "Total sessions: $SESSION_COUNT"
        log "SUCCESS" "End time: $(date)"
        exit 0
    fi

    # Brief pause before next session
    log "INFO" "Waiting 30 seconds before next session..."
    log "INFO" ""
    sleep 30
done

log "SUCCESS" "========================================="
log "SUCCESS" "Untranslated Entry Fix Completed"
log "SUCCESS" "========================================="
log "SUCCESS" "Total Sessions: $SESSION_COUNT"
log "SUCCESS" "Total Fixed: $TOTAL_FIXED"
log "SUCCESS" "End time: $(date)"

cleanup_claude
