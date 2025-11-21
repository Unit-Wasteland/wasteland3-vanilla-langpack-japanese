#!/bin/bash
##############################################################################
# Wasteland 3 Japanese Translation - Automated Retranslation Script
#
# Purpose: Fully automated retranslation with CLAUDE.md compliance
#
# CLAUDE.md Compliance: This script follows ALL rules in CLAUDE.md
# - Section 8: Space-Prefixed Entries - Special Handling
# - Quote Format Rules: Match English source quote count exactly
# - Structure Protection: No escapes, preserve markers
# - Translation Decision Logic: Default to translate
# - Sequential Processing: No skipping, no prioritization
# - Validation: Structure + Action Markers + Quality (all MANDATORY)
#
# IMPORTANT: Work Sequence (MANDATORY)
# 1. Base Game (169,712 entries) - MUST complete to 100% FIRST
# 2. DLC1 (38,554 entries) - Start ONLY after base game 100%
# 3. DLC2 (24,152 entries) - Start ONLY after DLC1 100%
#
# Current Implementation: ALL CONTENT SUPPORTED
# - Script detects current phase from progress file
# - Automatically uses correct file paths for base game, DLC1, or DLC2
# - Progress tracking covers all phases combined
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
MAX_SESSIONS=500            # Max 500 sessions for all content (232,418 entries ÷ 500)
MONITOR_INTERVAL=30         # Check memory every 30 seconds

# File paths for each phase
# Base game
BASE_GAME_TARGET="translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"
BASE_GAME_SOURCE="translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"
BASE_GAME_SPANISH="translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-f95544f6ef35e8a6587dccfa911ba0f8-9130184510981781208.txt"

# DLC1: Battle of Steeltown
DLC1_TARGET="translation/target/v1.6.9.420.309496/ja_JP/DLC1/StringTableData_English-CAB-01cf4ea31238681a8e1bd9559c0f3f3e--5815625736905989241.txt"
DLC1_SOURCE="translation/source/v1.6.9.420.309496/en_US/DLC1/StringTableData_English-CAB-01cf4ea31238681a8e1bd9559c0f3f3e--5815625736905989241.txt"
DLC1_SPANISH="translation/source/v1.6.9.420.309496/es_ES/DLC1/StringTableData_Spanish-CAB-01cf4ea31238681a8e1bd9559c0f3f3e-7305399230875977342.txt"

# DLC2: Cult of the Holy Detonation
DLC2_TARGET="translation/target/v1.6.9.420.309496/ja_JP/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt"
DLC2_SOURCE="translation/source/v1.6.9.420.309496/en_US/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt"
DLC2_SPANISH="translation/source/v1.6.9.420.309496/es_ES/DLC2/StringTableData_Spanish-CAB-6a212d8a4482b263f057ec8756825864-6420464141808439591.txt"

# NOTE: Total entries across all content
# - Base game: 169,712 entries
# - DLC1: 38,554 entries
# - DLC2: 24,152 entries
# - Total: 232,418 entries → ~465 sessions at 500 entries/session

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
# Returns TOTAL entries across all phases (base_game + dlc1 + dlc2)
get_progress_entries() {
    local progress_file="$WORKING_DIR/translation/.retranslation_progress.json"
    local base_entries dlc1_entries dlc2_entries

    base_entries=$(safe_jq_read '.base_game.entries_completed // 0' "$progress_file" 0)
    dlc1_entries=$(safe_jq_read '.dlc1.entries_completed // 0' "$progress_file" 0)
    dlc2_entries=$(safe_jq_read '.dlc2.entries_completed // 0' "$progress_file" 0)

    echo $((base_entries + dlc1_entries + dlc2_entries))
}

# Check if retranslation is complete (uses safe_jq_read)
is_retranslation_complete() {
    local progress_file="$WORKING_DIR/translation/.retranslation_progress.json"
    local status_dlc1 status_dlc2

    # Check DLC1 and DLC2 completion (base_game is implicitly complete when DLC1 starts)
    status_dlc1=$(safe_jq_read '.dlc1.status' "$progress_file" "not_started")
    status_dlc2=$(safe_jq_read '.dlc2.status' "$progress_file" "not_started")

    if [[ "$status_dlc1" == "completed" ]] && \
       [[ "$status_dlc2" == "completed" ]]; then
        return 0  # Complete
    fi
    return 1  # Not complete
}

# Get current phase from progress file
get_current_phase() {
    local progress_file="$WORKING_DIR/translation/.retranslation_progress.json"
    safe_jq_read '.current_phase' "$progress_file" "base_game"
}

# Get target file path based on current phase
get_target_file() {
    local phase="$1"
    case "$phase" in
        "base_game") echo "$BASE_GAME_TARGET" ;;
        "dlc1") echo "$DLC1_TARGET" ;;
        "dlc2") echo "$DLC2_TARGET" ;;
        *) echo "$BASE_GAME_TARGET" ;;
    esac
}

# Get source file path based on current phase
get_source_file() {
    local phase="$1"
    case "$phase" in
        "base_game") echo "$BASE_GAME_SOURCE" ;;
        "dlc1") echo "$DLC1_SOURCE" ;;
        "dlc2") echo "$DLC2_SOURCE" ;;
        *) echo "$BASE_GAME_SOURCE" ;;
    esac
}

# Get Spanish reference file path based on current phase
get_spanish_file() {
    local phase="$1"
    case "$phase" in
        "base_game") echo "$BASE_GAME_SPANISH" ;;
        "dlc1") echo "$DLC1_SPANISH" ;;
        "dlc2") echo "$DLC2_SPANISH" ;;
        *) echo "$BASE_GAME_SPANISH" ;;
    esac
}

# Get current line from progress file based on phase
get_current_line() {
    local progress_file="$WORKING_DIR/translation/.retranslation_progress.json"
    local phase="$1"
    case "$phase" in
        "base_game") safe_jq_read '.base_game.current_line // 390' "$progress_file" 390 ;;
        "dlc1") safe_jq_read '.dlc1.current_line // 1' "$progress_file" 1 ;;
        "dlc2") safe_jq_read '.dlc2.current_line // 1' "$progress_file" 1 ;;
        *) echo "1" ;;
    esac
}

# Main automation loop
log "INFO" "========================================="
log "INFO" "Wasteland 3 Retranslation Automation"
log "INFO" "========================================="
log "INFO" "✅ CLAUDE.md Compliance Mode: ALL rules enforced"
log "INFO" "   - Space-Prefixed Entries: Individual evaluation"
log "INFO" "   - Quote Format: Match English source exactly"
log "INFO" "   - Structure Protection: Zero tolerance"
log "INFO" "   - Sequential Processing: No skipping"
log "INFO" "   - Triple Validation: Structure + Markers + Quality"
log "INFO" ""
log "INFO" "Total Project Scope:"
log "INFO" "  Base Game: 169,712 entries"
log "INFO" "  DLC1 (Battle of Steeltown): 38,554 entries"
log "INFO" "  DLC2 (Cult of the Holy Detonation): 24,152 entries"
log "INFO" "  Total: 232,418 entries"
log "INFO" ""
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

    # Check for validation errors from previous session
    STRUCTURE_ERROR_FILE="$WORKING_DIR/automation/.structure_errors.log"
    QUALITY_ERROR_FILE="$WORKING_DIR/automation/.quality_errors.log"
    HAS_STRUCTURE_ERRORS=false
    HAS_QUALITY_ERRORS=false

    if [ -f "$STRUCTURE_ERROR_FILE" ] && [ -s "$STRUCTURE_ERROR_FILE" ]; then
        HAS_STRUCTURE_ERRORS=true
        log "WARN" "Structure errors detected from previous session - will prioritize fixing"
    fi

    if [ -f "$QUALITY_ERROR_FILE" ] && [ -s "$QUALITY_ERROR_FILE" ]; then
        HAS_QUALITY_ERRORS=true
        log "WARN" "Quality errors detected from previous session - will prioritize fixing"
    fi

    # Prepare command for Claude Code (STRICT WORKFLOW - based on STRICT_TRANSLATION_RULES.md)
    COMMAND_FILE="$WORKING_DIR/automation/.current_retranslate_command.txt"

    # Generate command based on whether errors need fixing
    if [ "$HAS_STRUCTURE_ERRORS" = true ] || [ "$HAS_QUALITY_ERRORS" = true ]; then
        # ERROR FIXING MODE
        log "INFO" "Generating error-fixing command..."
        cat > "$COMMAND_FILE" << 'EOF'
⚠️ **エラー修正モード - 優先タスク**

前回のセッションでvalidationエラーが検出されました。通常の翻訳作業の前に、まずこれらのエラーを修正してください。

**エラーレポートの確認:**
EOF

        if [ "$HAS_STRUCTURE_ERRORS" = true ]; then
            echo "1. 構造エラー: automation/.structure_errors.log を読み込んで詳細を確認" >> "$COMMAND_FILE"
        fi

        if [ "$HAS_QUALITY_ERRORS" = true ]; then
            echo "2. 品質エラー: automation/.quality_errors.log を読み込んで詳細を確認" >> "$COMMAND_FILE"
        fi

        cat >> "$COMMAND_FILE" << 'EOF'

**修正手順 (CLAUDE.mdルールに従った個別判断・自動修正):**

1. **エラーレポートの解析**:
   - 各エラーの行番号、問題の種類、詳細を把握
   - エラーの優先順位付け（構造エラー → 品質エラー）

2. **個別エラーの修正** (MANDATORY - CLAUDE.mdルールに従う):
   - 各エラーについて、CLAUDE.mdの該当ルールを適用
   - Readツールで該当箇所を読み込み
   - Editツールで正しい形式に修正
   - 一度に1つのエラーを処理（バッチ処理禁止）

3. **修正後の検証** (各修正ごとにMUSTで実行):

   a) **構造検証**:
      python3 translation/validate_structure_v2.py \
        translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt \
        --source translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt \
        --detailed
      → エラー数: 0 であることを確認

   b) **アクションマーカー検証**:
      grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt
      → 結果が空であること確認

   c) **品質検証**:
      python3 translation/validate_translation_quality.py \
        translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt \
        --reference translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-f95544f6ef35e8a6587dccfa911ba0f8-9130184510981781208.txt \
        --start-line 390 \
        --end-line CURRENT_LINE \
        --glossary translation/nouns_glossary.json
      → Total issues found: 0 であることを確認

4. **全エラー修正完了後**:
   - 全ての検証が0エラーを確認
   - git add -A
   - git commit -m "Fix validation errors (auto-correction)"
   - automation/.structure_errors.log 削除（該当する場合）
   - automation/.quality_errors.log 削除（該当する場合）

5. **通常翻訳作業への移行**:
   - エラー修正完了を確認
   - translation/.retranslation_progress.json を読み込み
   - 通常の翻訳作業を再開（以下の通常モード指示に従う）

---

**通常翻訳作業（エラー修正完了後に実行）:**

**CLAUDE.mdのルールに従って進捗ファイルから翻訳を続けてください。**

translation/.retranslation_progress.json を読み込んで、CLAUDE.md の全てのルールに従って翻訳作業を継続してください。

⚠️ **特に重要なCLAUDE.mdルール**:

**Section 8: Space-Prefixed Entries - Special Handling** (MANDATORY)

半角スペースで始まるエントリ（` エントリ内容`）は以下のプロセスで評価:

1. **エントリを読む**: 実際の内容を確認
2. **判断**: "プレイヤーがゲーム内でこのテキストを見るか？"
   - YES → 翻訳する（技術的コメントは括弧で保持）
   - NO → スキップ（純粋なデバッグ/システムメッセージ）

**Translation Decision Logic** (CLAUDE.md優先順):
1. 英語が空 → スキップ
2. do_not_translateリスト該当 → 英語のまま保持
3. nouns_glossary.json登録 → 用語集の訳語で翻訳
4. スペイン語が非空 かつ スペイン語 != 英語 → 翻訳
5. **それ以外 → 翻訳**（デフォルト）

**Quote Format Rules**: 英語ソースの引用符数と完全一致（1個も増減禁止）
**Structure Protection**: `\"` 禁止、`[]` `<>` `::action::` 保護、`\n` `\r` `\t` 保持
**Sequential Processing**: current_line から順番に、スキップ禁止、150-200行チャンク
**Validation**: 各edit後に構造・アクションマーカー・品質の3検証を全て実行（0エラー必須）
EOF

    else
        # NORMAL TRANSLATION MODE
        log "INFO" "Generating normal translation command..."
        cat > "$COMMAND_FILE" << 'EOF'
**CLAUDE.mdのルールに従って進捗ファイルから翻訳を続けてください。**

translation/.retranslation_progress.json を読み込んで、CLAUDE.md の全てのルールに従って翻訳作業を継続してください。

⚠️ **特に重要なCLAUDE.mdルール**:

**Section 8: Space-Prefixed Entries - Special Handling** (MANDATORY)

半角スペースで始まるエントリ（` エントリ内容`）は以下のプロセスで評価:

1. **エントリを読む**: 実際の内容を確認
2. **判断**: "プレイヤーがゲーム内でこのテキストを見るか？"
   - YES → 翻訳する（技術的コメントは括弧で保持）
   - NO → スキップ（純粋なデバッグ/システムメッセージ）

**翻訳すべき例（プレイヤー向け）**:
- ` おしゃべりは終わりだ - 離れるか戦う準備をしろ！(Conversation Ends)` ✅ 翻訳
- ` [Hard Ass 6] 指を離せ、さもないと折るぞ。(Requires Global: HardAss_6)` ✅ 翻訳

**スキップすべき例（デバッグ/システム）**:
- ` DEBUG - Test conversation flow` ❌ スキップ
- ` System: Internal state machine` ❌ スキップ

**Translation Decision Logic** (CLAUDE.md優先順):

1. 英語が空 (`""`) → スキップ
2. `do_not_translate`リスト該当 (Script Node, [Global:], [Switch to]等) → 英語のまま保持
3. `nouns_glossary.json`に登録 → 用語集の訳語で翻訳
4. スペイン語が非空 かつ スペイン語 != 英語 → 翻訳
5. **それ以外 → 翻訳**（デフォルト: 未翻訳固有名詞を防止）

**Quote Format Rules** (MANDATORY):

Unity StringTableは2つの引用符形式をサポート:
- **Format 1**: `string data = "Simple text"` (2 quotes)
- **Format 2**: `string data = ""Dialogue text""` (4 quotes)

**絶対ルール**: 英語ソースの引用符数と**完全一致**
- 英語が2個 → 日本語も2個
- 英語が4個 → 日本語も4個
- 1個も増減禁止

**Structure Protection** (ZERO TOLERANCE):
- ❌ エスケープシーケンス禁止: `\"`
- ❌ 日本語括弧を構造に使用禁止: `「」` `『』`
- ✅ テキスト内での日本語括弧は可: `"彼女は「こんにちは」と言った。"`
- ✅ `\n`, `\r`, `\t` は保持

**Sequential Processing**:
- 進捗ファイルの current_line から順番に処理
- スキップ禁止、優先度付け禁止
- 150-200行チャンクで処理

**Validation** (MANDATORY after EVERY edit):
1. Structure: `python3 translation/validate_structure_v2.py TARGET --source SOURCE`
2. Action markers: `grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET` → 空であること
3. Quality: `python3 translation/validate_translation_quality.py TARGET ...`

全ての検証が0エラーになるまでコミット禁止。
EOF
    fi

    # Append common instructions (same for both modes)
    cat >> "$COMMAND_FILE" << EOF

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
1. **統一された翻訳可否判断** (MANDATORY - FIXED 2025-11-06):
   - 各エントリを翻訳する前に、以下の優先順で判断
   - スペイン語ファイル: translation/source/v1.6.9.420.309496/es_ES/*.txt（参考情報として使用）

   **【統一された翻訳可否判定ロジック（優先順）】**:

   1. 英語が空 ("") の場合 → スキップ（本当に空のエントリ）

   2. do_not_translateリストに該当 (Script Node, [Global:], [Switch to]等)
      → 英語のまま保持（技術用語）

   3. nouns_glossary.jsonに登録がある（固有名詞: 人名、地名、勢力名）
      → 用語集の訳語で日本語に翻訳

   4. スペイン語が非空 かつ スペイン語 != 英語（スペイン語で翻訳されている）
      → 日本語に翻訳（通常の翻訳可能テキスト）

   5. それ以外（スペイン語が空 または スペイン語 == 英語）
      → 日本語に翻訳（デフォルト動作）
      → これには用語集未登録の固有名詞、対話、説明文などが含まれる

   **重要な変更点（2025-11-06）**:
   - スペイン語参照は参考情報であり、決定要因ではない
   - デフォルト動作は「翻訳する」（未翻訳固有名詞の防止）
   - do_not_translateリストに明示的に該当する場合のみ翻訳をスキップ
   - 固有名詞はスペイン語版で英語のままでも日本語に翻訳

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

3. **各編集後の検証** (MANDATORY - ENHANCED 2025-11-09):
   各editツール実行後、必ず以下を全て実行:

   a) **構造検証**:
      python3 translation/validate_structure_v2.py TARGET_FILE --source SOURCE_FILE --detailed
      → エラー数: 0 であることを確認

   b) **アクションマーカー検証** (2025-11-02追加):
      grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE
      → 結果が空であること (何も表示されない = OK)
      → 何か表示される = アクションマーカーに日本語が含まれている = 即座に修正

   c) **品質検証** (NEW - 2025-11-09追加 - 翻訳漏れ防止):
      python3 translation/validate_translation_quality.py TARGET_FILE \\
        --reference REFERENCE_FILE \\
        --start-line START_LINE \\
        --end-line END_LINE \\
        --glossary translation/nouns_glossary.json
      → Total issues found: 0 であることを確認
      → 特に "Untranslated English entries" が 0 であることを厳格に確認

   d) **エラーがある場合**:
      - 次の編集に進まず、即座に修正
      - 修正後、再度検証 (a), (b), (c) を全て実行
      - 全エラー・全課題解消まで繰り返す

   引用符の数が英語ソースと完全一致していることを確認（上記ルール2参照）

   ⚠️⚠️⚠️ **CRITICAL: 検証を1つでもスキップしてはならない**
   - 全ての検証が合格するまでコミットしない
   - 「たぶん大丈夫」という推測は禁止
   - 必ず実際にスクリプトを実行して確認

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
        log "INFO" "Cumulative total: $END_ENTRIES entries (base + dlc1 + dlc2)"
        log "INFO" "  Total progress: $END_ENTRIES / 232,418 entries"
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

        # Get current phase and file paths for validation
        CURRENT_PHASE=$(get_current_phase)
        TARGET_FILE="$WORKING_DIR/$(get_target_file "$CURRENT_PHASE")"
        SOURCE_FILE="$WORKING_DIR/$(get_source_file "$CURRENT_PHASE")"
        REFERENCE_FILE="$WORKING_DIR/$(get_spanish_file "$CURRENT_PHASE")"
        CURRENT_LINE=$(get_current_line "$CURRENT_PHASE")

        log "INFO" "Current phase: $CURRENT_PHASE"

        # Validate structure before pushing
        log "INFO" "Running structure validation..."
        STRUCTURE_ERROR_FILE="$WORKING_DIR/automation/.structure_errors.log"
        rm -f "$STRUCTURE_ERROR_FILE"  # Clear old errors

        if ! python3 "$WORKING_DIR/translation/validate_structure_v2.py" \
            "$TARGET_FILE" \
            --source "$SOURCE_FILE" \
            --detailed > "$STRUCTURE_ERROR_FILE" 2>&1; then
            log "WARN" "✗ Structure validation FAILED - errors saved to .structure_errors.log"
            log "WARN" "  Next session will automatically fix these errors"
            # Don't exit - continue to push current progress and let next session fix
        else
            log "INFO" "✓ Structure validation passed"
            rm -f "$STRUCTURE_ERROR_FILE"  # No errors, clean up
        fi

        # Validate translation quality (action markers, untranslated entries)
        log "INFO" "Running quality validation..."
        QUALITY_ERROR_FILE="$WORKING_DIR/automation/.quality_errors.log"
        rm -f "$QUALITY_ERROR_FILE"  # Clear old errors

        # Start line depends on phase
        local START_LINE=1
        if [[ "$CURRENT_PHASE" == "base_game" ]]; then
            START_LINE=390
        fi

        if ! python3 "$WORKING_DIR/translation/validate_translation_quality.py" \
            "$TARGET_FILE" \
            --reference "$REFERENCE_FILE" \
            --start-line "$START_LINE" \
            --end-line "$CURRENT_LINE" \
            --glossary "$WORKING_DIR/translation/nouns_glossary.json" > "$QUALITY_ERROR_FILE" 2>&1; then
            log "WARN" "✗ Quality validation FAILED - errors saved to .quality_errors.log"
            log "WARN" "  Next session will automatically fix these errors"
            # Don't exit - continue to push current progress and let next session fix
        else
            log "INFO" "✓ Quality validation passed (no action marker or untranslated issues)"
            rm -f "$QUALITY_ERROR_FILE"  # No errors, clean up
        fi

        # Push to remote after validation (even if validation found errors to fix later)
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
