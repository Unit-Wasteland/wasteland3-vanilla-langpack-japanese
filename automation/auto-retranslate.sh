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

# Clean up old Claude Code history files to prevent disk space issues
cleanup_history() {
    local history_dir="/home/claude/.claude/projects/-home-claude-work-project-claude-wasteland3-vanilla-langpack-japanese"

    if [ ! -d "$history_dir" ]; then
        log "WARN" "History directory not found: $history_dir"
        return
    fi

    # Get current disk usage
    local before_size=$(du -sm "$history_dir" 2>/dev/null | awk '{print $1}')
    local file_count=$(find "$history_dir" -name "*.jsonl" -type f | wc -l)

    log "INFO" "History cleanup: Directory size ${before_size}MB, File count: $file_count"

    # Strategy 1: Remove files older than 3 days (conservative approach)
    local deleted_old=0
    while IFS= read -r file; do
        rm -f "$file"
        deleted_old=$((deleted_old + 1))
    done < <(find "$history_dir" -name "*.jsonl" -type f -mtime +3)

    if [ $deleted_old -gt 0 ]; then
        log "INFO" "  Deleted $deleted_old history files older than 3 days"
    fi

    # Strategy 2: If still large (>30GB), keep only 50 most recent files
    local after_size=$(du -sm "$history_dir" 2>/dev/null | awk '{print $1}')
    if [ $after_size -gt 30720 ]; then  # 30GB = 30720MB
        log "WARN" "  Directory still large (${after_size}MB > 30GB), keeping only 50 most recent files"

        # Get all .jsonl files sorted by modification time (oldest first)
        # Delete all except the 50 most recent
        local deleted_excess=0
        while IFS= read -r file; do
            rm -f "$file"
            deleted_excess=$((deleted_excess + 1))
        done < <(find "$history_dir" -name "*.jsonl" -type f -printf "%T@ %p\n" | sort -n | head -n -50 | awk '{print $2}')

        if [ $deleted_excess -gt 0 ]; then
            log "INFO" "  Deleted $deleted_excess excess history files (kept 50 most recent)"
        fi
    fi

    # Final statistics
    local final_size=$(du -sm "$history_dir" 2>/dev/null | awk '{print $1}')
    local final_count=$(find "$history_dir" -name "*.jsonl" -type f | wc -l)
    local freed_mb=$((before_size - final_size))

    log "INFO" "  Cleanup complete: ${freed_mb}MB freed, ${final_count} files remaining (${final_size}MB)"
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

# Helper function: safe JSON read with retry logic
safe_jq_read() {
    local jq_query="$1"
    local json_file="$2"
    local default_value="${3:-0}"

    if [ ! -f "$json_file" ]; then
        echo "$default_value"
        return
    fi

    # Retry up to 5 times with exponential backoff
    local max_retries=5
    local retry=0
    local result

    while [ $retry -lt $max_retries ]; do
        # Small delay to ensure file write is complete
        sleep 0.2

        # Attempt to read JSON with jq
        result=$(jq -r "$jq_query" "$json_file" 2>/dev/null)
        local jq_exit_code=$?

        # Success - return result
        if [ $jq_exit_code -eq 0 ] && [ ! -z "$result" ]; then
            echo "$result"
            return
        fi

        # Failed - retry
        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            log "WARN" "JSON read failed (attempt $retry/$max_retries), retrying in $((retry * 2)) seconds..." >&2
            sleep $((retry * 2))
        fi
    done

    # All retries failed - use fallback
    log "ERROR" "Failed to read JSON after $max_retries attempts (query: $jq_query), using fallback: $default_value" >&2
    echo "$default_value"
}

# Validate JSON file structure
validate_json() {
    local json_file="$1"

    if [ ! -f "$json_file" ]; then
        log "ERROR" "JSON validation failed: File not found: $json_file"
        return 1
    fi

    # Validate with jq (checks syntax)
    if ! jq empty "$json_file" >/dev/null 2>&1; then
        log "ERROR" "JSON validation failed: Invalid JSON syntax in $json_file"
        jq empty "$json_file" 2>&1 | head -5 | while read line; do
            log "ERROR" "  $line"
        done
        return 1
    fi

    log "INFO" "✓ JSON validation passed: $json_file"
    return 0
}

# Create backup of progress file
backup_progress_file() {
    local progress_file="$1"
    local backup_file="${progress_file}.backup"

    if [ ! -f "$progress_file" ]; then
        log "WARN" "Progress file not found, skipping backup: $progress_file"
        return 1
    fi

    # Only backup if current file is valid JSON
    if validate_json "$progress_file"; then
        cp "$progress_file" "$backup_file"
        log "INFO" "✓ Progress file backed up: ${backup_file}"
        return 0
    else
        log "ERROR" "Cannot backup invalid JSON file"
        return 1
    fi
}

# Restore progress file from backup if current is corrupted
restore_progress_file() {
    local progress_file="$1"
    local backup_file="${progress_file}.backup"

    if [ ! -f "$backup_file" ]; then
        log "ERROR" "Backup file not found: $backup_file"
        return 1
    fi

    # Validate backup before restoring
    if validate_json "$backup_file"; then
        cp "$backup_file" "$progress_file"
        log "INFO" "✓ Progress file restored from backup"
        return 0
    else
        log "ERROR" "Backup file is also corrupted, cannot restore"
        return 1
    fi
}

# Read retranslation progress (uses safe_jq_read)
get_progress_entries() {
    local progress_file="$WORKING_DIR/translation/.retranslation_progress.json"
    safe_jq_read '.total_entries_completed // 0' "$progress_file" 0
}

# Check if retranslation is complete (uses safe_jq_read)
is_retranslation_complete() {
    local progress_file="$WORKING_DIR/translation/.retranslation_progress.json"
    local status_base status_dlc1 status_dlc2

    status_base=$(safe_jq_read '.files.base_game.status' "$progress_file" "in_progress")
    status_dlc1=$(safe_jq_read '.files.dlc1.status' "$progress_file" "pending")
    status_dlc2=$(safe_jq_read '.files.dlc2.status' "$progress_file" "pending")

    if [[ "$status_base" == "completed" ]] && \
       [[ "$status_dlc1" == "completed" ]] && \
       [[ "$status_dlc2" == "completed" ]]; then
        return 0  # Complete
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

# Clean up old history files at startup
cleanup_history

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

    # Backup progress file BEFORE session starts
    PROGRESS_FILE="$WORKING_DIR/translation/.retranslation_progress.json"
    if ! backup_progress_file "$PROGRESS_FILE"; then
        log "ERROR" "Failed to backup progress file, attempting restore..."
        if restore_progress_file "$PROGRESS_FILE"; then
            log "INFO" "Progress file restored, retrying backup..."
            backup_progress_file "$PROGRESS_FILE" || {
                log "ERROR" "Cannot create valid backup, aborting session"
                exit 1
            }
        else
            log "ERROR" "Cannot restore progress file, aborting"
            exit 1
        fi
    fi

    # Get current progress
    START_ENTRIES=$(get_progress_entries)
    log "INFO" "Current progress: $START_ENTRIES entries completed"

    # Prepare command for Claude Code (STRICT WORKFLOW - based on STRICT_TRANSLATION_RULES.md)
    COMMAND_FILE="$WORKING_DIR/automation/.current_retranslate_command.txt"
    cat > "$COMMAND_FILE" << EOF
translation/.retranslation_progress.json を読み込んで、translation/STRICT_TRANSLATION_RULES.md に従って厳格翻訳作業を継続してください。

⚠️ **自動実行モード**:
- メインセッションで直接作業（サブエージェント不使用）
- 全ての権限リクエストは自動承認
- 質問や確認なしで作業を進める

🔴🔴🔴 **絶対に守るべき2つの重大ルール** (Session 193エラー防止) 🔴🔴🔴

**ルール1: スペイン語が空なら英語テキストを保持 (削除禁止!)**
❌ 間違い: EN=""Hiya, Rangers"" (4 quotes), ES="" (empty) → JA="" (2 quotes) - 削除してはダメ!
✅ 正解:   EN=""Hiya, Rangers"" (4 quotes), ES="" (empty) → JA=""Hiya, Rangers"" (4 quotes) - 英語のまま保持!

**ルール2: 引用符の数を英語ソースと完全一致させる (1個も増減禁止!)**
❌ 間違い: EN has "\n\n\n" (quote, newlines, quote) → JA has ""\n\n\n"" (quote-quote, newlines, quote-quote)
✅ 正解:   EN has "\n\n\n" (quote, newlines, quote) → JA has "\n\n\n" (quote, newlines, quote) - 完全一致!
- 対話の区切りで引用符を追加・削除してはいけない
- ENが4個なら → JAも必ず4個
- ENが6個なら → JAも必ず6個

⚠️ **厳格ワークフロー要件** (STRICT_TRANSLATION_RULES.md):
1. **スペイン語参照による翻訳可否判断** (MANDATORY):
   - 各エントリを翻訳する前に、対応するスペイン語ファイルの同じ行を確認
   - スペイン語で翻訳されている → 日本語でも翻訳可能
   - スペイン語で英語のまま → プログラム識別子なので英語のまま残す
   - スペイン語が空 ("") → 英語テキストをそのまま保持（上記ルール1参照）
   - スペイン語ファイル: translation/source/v1.6.9.420.309496/es_ES/*.txt

2. **構造保護ルール厳守** (STRUCTURE_PROTECTION_RULES.md):
   - ⚠️⚠️⚠️ **\\r\\n エスケープシーケンスを絶対に実際の改行に変換しない**
   - "" マーカー保護（「」『』に変換禁止）- Unity形式必須
   - []、<> 保護
   - [Global:], [Dropset:], [Reward:] など絶対に翻訳禁止
   - Script Node 翻訳禁止

   ⚠️⚠️⚠️ **CRITICAL: ::action:: マーカー保護 (ZERO TOLERANCE)** ⚠️⚠️⚠️

   **アクションマーカーとは**: ゲームエンジン制御コマンド (形式: ::action::)
   例: ::sigh::, ::laughs::, ::nods::, ::static::, ::gunfire::, ::hums quietly::

   **絶対ルール**:
   ❌ **絶対禁止**: アクションマーカー内容を日本語に翻訳
   ❌ **絶対禁止**: アクションマーカーを削除・変更
   ✅ **正しい処理**: 英語のまま、文字単位で完全一致保持

   **悪い例 (NG - ゲームが壊れる)**:
   EN: string data = "::sigh:: \"I don't know...\""
   JA: string data = "::ため息:: \"わからない...\"" ❌ WRONG!

   **正しい例 (OK)**:
   EN: string data = "::sigh:: \"I don't know...\""
   JA: string data = "::sigh:: \"わからない...\"" ✅ CORRECT!

3. **各編集後の検証** (MANDATORY):
   各editツール実行後、必ず以下を実行:

   a) **構造検証**:
      python3 translation/validate_structure_v2.py TARGET_FILE --source SOURCE_FILE --detailed
      → エラー数: 0 であることを確認

   b) **アクションマーカー検証** (NEW - 2025-11-02追加):
      grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE
      → 結果が空であること (何も表示されない = OK)
      → 何か表示される = アクションマーカーに日本語が含まれている = 即座に修正

   c) **エラーがある場合**:
      - 次の編集に進まず、即座に修正
      - 修正後、再度検証 (a) と (b) を実行
      - 全エラー解消まで繰り返す

   引用符の数が英語ソースと完全一致していることを確認（上記ルール2参照）

4. **シーケンシャル処理** (MANDATORY):
   - 現在の行位置から順番に処理（スキップ禁止）
   - 150-200行チャンクで処理（メモリ効率最大化）
   - 優先度付けや長文優先処理は厳格に禁止

5. **用語集参照**: nouns_glossary.json を参照して一貫した訳語を使用

6. **JSON安全性ガイドライン** (CRITICAL - 再発防止):
   - ⚠️⚠️⚠️ 進捗ファイルの "note" フィールドに書き込む際の重要ルール:
   - **絶対禁止**: noteフィールド内で "" (ダブルダブルクォート) を使用しない
   - **絶対禁止**: noteフィールド内で \" (バックスラッシュクォート) を使用しない
   - **推奨**: 引用符を説明する際は "double-double-quote format" や "4-quote format" など英語表現を使用
   - **推奨**: \r\n を説明する際は "escape sequences" や "newline markers" など英語表現を使用
   - **理由**: JSONパーサーがエスケープされていない引用符でエラーになる
   - **例**: ❌ 'Quote format: "" strictly maintained' → ✅ 'Quote format: double-quote markers strictly maintained'

目標: 約${ENTRIES_PER_SESSION}エントリを処理してコミット・プッシュ

処理完了後、以下の形式で報告:
- 翻訳完了エントリ数: XXXX
- 最新コミットハッシュ: XXXXXXX
- 検証結果: エラー数・警告数
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

    # Validate progress file JSON after session
    log "INFO" "Validating progress file JSON integrity..."
    if ! validate_json "$PROGRESS_FILE"; then
        log "ERROR" "Progress file corrupted after session, attempting rollback..."
        if restore_progress_file "$PROGRESS_FILE"; then
            log "INFO" "✓ Progress file successfully rolled back to pre-session state"
            log "WARN" "Session #$SESSION_COUNT results discarded due to JSON corruption"
            log "WARN" "Check session output for problematic JSON writes: $OUTPUT_FILE"
            # Count as zero-entry session to trigger safety check
            ENTRIES_THIS_SESSION=0
        else
            log "ERROR" "CRITICAL: Cannot restore progress file from backup!"
            log "ERROR" "Manual intervention required"
            log "ERROR" "Session output: $OUTPUT_FILE"
            exit 1
        fi
    else
        # Get progress after session (only if JSON is valid)
        END_ENTRIES=$(get_progress_entries)
        ENTRIES_THIS_SESSION=$((END_ENTRIES - START_ENTRIES))
        TOTAL_ENTRIES=$((TOTAL_ENTRIES + ENTRIES_THIS_SESSION))

        log "INFO" "Session #$SESSION_COUNT completed: $ENTRIES_THIS_SESSION entries translated"
        log "INFO" "Cumulative total: $END_ENTRIES entries (out of ~71,992)"
    fi

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

        # Validate structure before pushing
        log "INFO" "Running structure validation..."
        if bash "$WORKING_DIR/automation/validate-structure.sh" >> "$LOG_FILE" 2>&1; then
            log "INFO" "✓ Structure validation passed"
        else
            log "WARN" "✗ Structure validation FAILED!"
            log "WARN" "  Attempting auto-fix..."

            # Attempt auto-fix
            if bash "$WORKING_DIR/automation/auto-fix-errors.sh" "$LOG_FILE"; then
                log "INFO" "✓ Auto-fix completed - retrying validation"

                # Retry validation
                if bash "$WORKING_DIR/automation/validate-structure.sh" >> "$LOG_FILE" 2>&1; then
                    log "INFO" "✓ Structure validation passed after auto-fix"

                    # Commit auto-fix changes
                    log "INFO" "Committing auto-fix changes..."
                    cd "$WORKING_DIR"
                    git add -A
                    AUTOFIX_COMMIT_MSG="Auto-fix: Structure errors (Session #$SESSION_COUNT)

Automated error correction by auto-fix-errors.sh

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
                    if git commit -m "$AUTOFIX_COMMIT_MSG" >> "$LOG_FILE" 2>&1; then
                        log "INFO" "✓ Auto-fix changes committed"
                    else
                        log "WARN" "⚠ No changes to commit (auto-fix may have been no-op)"
                    fi
                else
                    log "ERROR" "✗ Structure validation still failing after auto-fix"
                    log "ERROR" "  File structure is corrupted - manual review required"
                    log "ERROR" "  Session output: $OUTPUT_FILE"
                    log "ERROR" "  Stopping automation to prevent data loss"
                    exit 1
                fi
            else
                log "ERROR" "✗ Auto-fix failed - cannot recover automatically"
                log "ERROR" "  Session output: $OUTPUT_FILE"
                log "ERROR" "  Stopping automation - manual intervention required"
                exit 1
            fi
        fi

        # Validate translation quality (action markers, untranslated entries)
        log "INFO" "Running quality validation..."
        TARGET_FILE="$WORKING_DIR/translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"
        REFERENCE_FILE="$WORKING_DIR/translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-f95544f6ef35e8a6587dccfa911ba0f8-9130184510981781208.txt"

        # Get current translation range from progress file
        CURRENT_LINE=$(safe_jq_read '.files.base_game.current_line // 390' "$PROGRESS_FILE" 390)

        # Run quality validation on translated range (from line 390 to current line)
        # Use Spanish reference to determine if English text should be translated
        if python3 "$WORKING_DIR/translation/validate_translation_quality.py" \
            "$TARGET_FILE" \
            --reference "$REFERENCE_FILE" \
            --start-line 390 \
            --end-line "$CURRENT_LINE" >> "$LOG_FILE" 2>&1; then
            log "INFO" "✓ Quality validation passed (no action marker or untranslated issues)"
        else
            log "WARN" "✗ Quality validation FAILED!"
            log "WARN" "  Attempting auto-fix..."

            # Attempt auto-fix
            if bash "$WORKING_DIR/automation/auto-fix-errors.sh" "$LOG_FILE"; then
                log "INFO" "✓ Auto-fix completed - retrying validation"

                # Retry validation
                if python3 "$WORKING_DIR/translation/validate_translation_quality.py" \
                    "$TARGET_FILE" \
                    --reference "$REFERENCE_FILE" \
                    --start-line 390 \
                    --end-line "$CURRENT_LINE" >> "$LOG_FILE" 2>&1; then
                    log "INFO" "✓ Quality validation passed after auto-fix"

                    # Commit auto-fix changes
                    log "INFO" "Committing auto-fix changes..."
                    cd "$WORKING_DIR"
                    git add -A
                    AUTOFIX_COMMIT_MSG="Auto-fix: Quality errors (Session #$SESSION_COUNT)

Automated error correction by auto-fix-errors.sh
Fixed action markers and translation quality issues

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
                    if git commit -m "$AUTOFIX_COMMIT_MSG" >> "$LOG_FILE" 2>&1; then
                        log "INFO" "✓ Auto-fix changes committed"
                    else
                        log "WARN" "⚠ No changes to commit (auto-fix may have been no-op)"
                    fi
                else
                    log "ERROR" "✗ Quality validation still failing after auto-fix"
                    log "ERROR" "  Translation quality issues persist - manual review required"
                    log "ERROR" "  Session output: $OUTPUT_FILE"
                    log "ERROR" "  Stopping automation"
                    exit 1
                fi
            else
                log "ERROR" "✗ Auto-fix failed - cannot recover automatically"
                log "ERROR" "  Session output: $OUTPUT_FILE"
                log "ERROR" "  Stopping automation - manual intervention required"
                exit 1
            fi
        fi

        # Push to remote after successful progress and validation
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

    # Clean up history files between sessions (if progress was made)
    if [ $ENTRIES_THIS_SESSION -gt 0 ]; then
        cleanup_history
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
