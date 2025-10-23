#!/bin/bash

##############################################################################
# Wasteland 3 Japanese Translation - Automated Retranslation Script
#
# Purpose: Fully automated retranslation with structure protection
#
# Strategy:
# - Use English files as base (structure preservation)
# - Extract Japanese from backup_broken (reuse existing translations)
# - Protect structure markers ("", [], <>, ::, etc.)
# - Translate untranslated entries (English → Japanese)
# - Full automation with memory management
#
# Usage:
#   ./automation/auto-retranslate.sh         # Start automated retranslation
#   ./automation/auto-retranslate.sh --unlock # Remove lock file and exit
#
# Requirements:
# - Claude Code CLI installed
# - English source files in translation/source/v1.6.9.420.309496/en_US/
# - Broken translations in translation/backup_broken/
# - Progress file: translation/.retranslation_progress.json
#
# Memory Management:
# - 2GB: Warning threshold (reduce chunk size)
# - 2.5GB: Mandatory session restart (Node.js heap limit)
# - Progress persisted in .retranslation_progress.json
# - Session timeout: 30 minutes (prevent CLI memory accumulation)
#
# Safety Features:
# - 20-line chunk processing (never exceed 20 lines)
# - 30-entry commit frequency (frequent memory release)
# - 50-entry session limit (prevent JSON.stringify RangeError)
# - Structure validation after each edit
# - 3 consecutive zero-progress sessions → abort
#
# Output:
# - All logs → automation/retranslation-automation.log
# - Session logs → automation/.session_N_output.log
##############################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly PROGRESS_FILE="$PROJECT_DIR/translation/.retranslation_progress.json"
readonly LOG_FILE="$SCRIPT_DIR/retranslation-automation.log"
readonly COMMAND_FILE="$SCRIPT_DIR/.current_retranslate_command.txt"
readonly LOCK_FILE="$SCRIPT_DIR/.retranslation.lock"

# Session tracking
SESSION_COUNT=0
CONSECUTIVE_ZERO_SESSIONS=0
readonly MAX_ZERO_SESSIONS=3

# Logging function
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $*"
    exit 1
}

# Lock file management
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")

        # Check if the process is still running
        if [[ "$lock_pid" != "unknown" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            error_exit "Another retranslation session is already running (PID: $lock_pid)"
        else
            log "Removing stale lock file (PID: $lock_pid no longer running)"
            rm -f "$LOCK_FILE"
        fi
    fi

    echo "$$" > "$LOCK_FILE"
    log "Lock acquired (PID: $$)"
}

release_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
        log "Lock released"
    fi
}

# Ensure lock is released on exit
trap release_lock EXIT INT TERM

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check Claude Code CLI
    if ! command -v claude &> /dev/null; then
        error_exit "Claude Code CLI not found. Please install it first."
    fi

    # Check progress file
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        error_exit "Progress file not found: $PROGRESS_FILE"
    fi

    # Check source files
    if [[ ! -d "$PROJECT_DIR/translation/source/v1.6.9.420.309496/en_US" ]]; then
        error_exit "English source files not found"
    fi

    # Check backup_broken
    if [[ ! -d "$PROJECT_DIR/translation/backup_broken" ]]; then
        error_exit "backup_broken directory not found"
    fi

    log "Prerequisites check: OK"
}

# Get progress statistics
get_progress_stats() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        local total_completed
        total_completed=$(jq -r '.total_entries_completed // 0' "$PROGRESS_FILE")
        echo "$total_completed"
    else
        echo "0"
    fi
}

# Check if retranslation is complete
is_retranslation_complete() {
    local status_base status_dlc1 status_dlc2
    status_base=$(jq -r '.files.base_game.status' "$PROGRESS_FILE")
    status_dlc1=$(jq -r '.files.dlc1.status' "$PROGRESS_FILE")
    status_dlc2=$(jq -r '.files.dlc2.status' "$PROGRESS_FILE")

    if [[ "$status_base" == "completed" ]] && \
       [[ "$status_dlc1" == "completed" ]] && \
       [[ "$status_dlc2" == "completed" ]]; then
        return 0  # Complete
    else
        return 1  # Not complete
    fi
}

# Create Claude Code command
create_claude_command() {
    cat > "$COMMAND_FILE" << 'EOF'
translation/.retranslation_progress.json を読み込んで、translation/RETRANSLATION_WORKFLOW.md に従って翻訳やり直し作業を継続してください。

**サーバー環境: Ubuntu 6GB RAM（メモリ制約あり）**

**重要な処理パラメータ（STRICTLY ENFORCE）:**
- read_chunk_size: 20行（ABSOLUTELY NEVER exceed 20 lines per Read operation）
- batch_size: 20エントリ（1つずつ処理、バッチ処理禁止）
- commit_frequency: 30エントリごと（より頻繁にコミット）
- **session_max_entries: 50エントリ** - このセッションで最大50エントリ処理したら必ず終了
- メモリ安全モード: **最優先**（物理メモリ6GB制約）

**CRITICAL メモリ管理規則（6GB RAM サーバー）:**
- ⚠️ **Node.js heap limit: 2.5GB** - 絶対に超えないこと
- ⚠️ 530K行ファイルの全体読み込みは絶対禁止
- ⚠️ Read tool は必ず offset + limit を指定（**最大20行**）
- ⚠️ 大きな変数の保持を避ける（処理後すぐ解放）
- ⚠️ **30エントリごとに必ずコミット**（メモリリセット）
- ⚠️ **50エントリ処理したら必ずセッション終了**（CLIメモリ制限）
- ⚠️ 一度に複数ファイルを開かない（1ファイルずつ）

**構造保護（CRITICAL）:**
- 絶対に変更禁止: "" [] <> ' ::action::
- Script Node は翻訳禁止
- 行数は絶対に変更禁止

**処理戦略（Sequential Only - 低メモリ最適化）:**
1. backup_brokenから20行チャンクで日本語テキストを抽出
2. 英語ファイルから対応する20行チャンクを読み込み
3. テキスト部分のみ安全に置換（1エントリずつ、順次処理）
4. 未翻訳は英語→日本語に翻訳（nouns_glossary.json参照）
5. **30エントリごとに必ずコミット**（メモリプレッシャー軽減）
6. **50エントリ処理後は必ずこのセッションを終了**（CLI crash防止）

**検証（MANDATORY）:**
- 各エディット後に行数一致確認
- 構造マーカー破損チェック
- 中国語混入チェック

**目標: 30-50エントリ/セッション（JSON.stringify error防止）**
より小さいチャンク、より頻繁なコミット、早期セッション終了で安定性を確保してください。

**⚠️ CRITICAL: このセッションで50エントリ処理したら必ず終了してください。**
CLI の会話履歴が大きくなりすぎて JSON.stringify RangeError が発生するのを防ぐため。

作業を開始してください。
EOF
}

# Get Claude Code memory usage
get_claude_memory() {
    # Get memory usage in MB for all claude processes (excluding current session)
    ps aux | grep 'claude --dangerously-skip-permissions' | grep -v grep | awk '{sum+=$6} END {print int(sum/1024)}'
}

# Check session log for errors
check_session_health() {
    local session_log="$1"
    local has_errors=0

    # Check if log file is empty or very small (< 100 bytes)
    if [[ ! -s "$session_log" ]] || [[ $(stat -c%s "$session_log") -lt 100 ]]; then
        log "⚠ WARNING: Session log is empty or too small (possible crash)"
        has_errors=1
    fi

    # Check for JSON.stringify errors (CLI crash)
    if grep -q "RangeError: Invalid string length" "$session_log" 2>/dev/null; then
        log "⚠ WARNING: Detected JSON.stringify error (CLI memory issue)"
        has_errors=1
    fi

    # Check for Node.js heap errors
    if grep -q "JavaScript heap out of memory" "$session_log" 2>/dev/null; then
        log "⚠ WARNING: Detected heap out of memory error"
        has_errors=1
    fi

    # Check for unhandled promise rejections
    if grep -q "UnhandledPromiseRejectionWarning" "$session_log" 2>/dev/null; then
        log "⚠ WARNING: Detected unhandled promise rejection"
        has_errors=1
    fi

    return $has_errors
}

# Check for uncommitted changes
check_uncommitted_work() {
    if ! git diff --quiet 2>/dev/null; then
        log "⚠ WARNING: Uncommitted changes detected in working directory"
        log "  Run: git status"
        log "  Files with changes:"
        git diff --name-only | head -5 | while read -r file; do
            log "    - $file"
        done
        return 1
    fi
    return 0
}

# Run single Claude Code session
run_claude_session() {
    SESSION_COUNT=$((SESSION_COUNT + 1))  # Avoid ((SESSION_COUNT++)) issue with set -e
    local session_log="$SCRIPT_DIR/.session_${SESSION_COUNT}_output.log"

    log "========================================="
    log "Starting session #$SESSION_COUNT"
    log "========================================="

    # Get progress before session
    local progress_before
    progress_before=$(get_progress_stats)
    log "Progress before session: $progress_before entries completed"

    # Create command file
    log "DEBUG: Creating command file..."
    create_claude_command
    log "DEBUG: Command file created at: $COMMAND_FILE"

    # Run Claude Code with automatic permission approval (background with timeout)
    log "Executing Claude Code session..."

    # Memory thresholds (in MB) - Optimized for 6GB physical RAM
    local WARN_MEMORY_MB=2048   # 2GB warning (conservative for 6GB system)
    local MAX_MEMORY_MB=2560    # 2.5GB mandatory restart (leave headroom for OS)

    log "DEBUG: Starting timeout command..."
    # Start Claude Code in background with timeout (30 minutes to prevent CLI memory accumulation)
    # Set Node.js heap size to 2.5GB (optimal for 6GB physical RAM server)
    # Leaves ~3.5GB for OS and other processes
    timeout 1800 bash -c "export NODE_OPTIONS='--max-old-space-size=2560'; yes | cat '$COMMAND_FILE' | claude --dangerously-skip-permissions" > "$session_log" 2>&1 &
    local CLAUDE_PID=$!

    log "Claude Code session started (PID: $CLAUDE_PID)"
    log "DEBUG: Session log file: $session_log"

    # Monitor memory usage
    local MONITOR_INTERVAL=30  # Check every 30 seconds
    log "DEBUG: Entering memory monitoring loop..."
    while kill -0 $CLAUDE_PID 2>/dev/null; do
        sleep $MONITOR_INTERVAL

        local MEMORY
        MEMORY=$(get_claude_memory)
        log "Memory usage: ${MEMORY}MB (Warning: ${WARN_MEMORY_MB}MB, Max: ${MAX_MEMORY_MB}MB)"

        if [[ $MEMORY -gt $MAX_MEMORY_MB ]]; then
            log "WARNING: Memory threshold exceeded (${MEMORY}MB > ${MAX_MEMORY_MB}MB), terminating session"
            kill -TERM $CLAUDE_PID 2>/dev/null || true
            sleep 2
            kill -KILL $CLAUDE_PID 2>/dev/null || true
            break
        elif [[ $MEMORY -gt $WARN_MEMORY_MB ]]; then
            log "WARNING: Memory approaching limit (${MEMORY}MB > ${WARN_MEMORY_MB}MB)"
        fi
    done

    log "DEBUG: Exited memory monitoring loop, waiting for Claude process..."
    # Wait for Claude Code to finish (capture exit code but don't trigger set -e)
    set +e  # Temporarily disable exit on error
    wait $CLAUDE_PID 2>/dev/null
    local exit_code=$?
    set -e  # Re-enable exit on error
    log "DEBUG: Claude process finished with exit code: $exit_code"

    if [[ $exit_code -eq 0 ]]; then
        log "Session #$SESSION_COUNT completed successfully"
    elif [[ $exit_code -eq 124 ]]; then
        log "WARNING: Session #$SESSION_COUNT timed out (30 minute limit)"
    else
        log "WARNING: Session #$SESSION_COUNT exited with status $exit_code (may be normal)"
    fi

    # Check session health (detect crashes)
    local session_has_errors=0
    if ! check_session_health "$session_log"; then
        session_has_errors=1
    fi

    # Check for uncommitted work
    if ! check_uncommitted_work; then
        log "⚠ WARNING: Found uncommitted changes - CLI may have crashed before committing"
        session_has_errors=1
    fi

    # Get progress after session
    local progress_after
    progress_after=$(get_progress_stats)
    local entries_completed=$((progress_after - progress_before))

    log "Progress after session: $progress_after entries completed"
    log "Entries completed this session: $entries_completed"

    # Check for zero progress
    if [[ $entries_completed -eq 0 ]]; then
        CONSECUTIVE_ZERO_SESSIONS=$((CONSECUTIVE_ZERO_SESSIONS + 1))  # Avoid ((...++)) issue with set -e
        log "WARNING: Zero entries completed (consecutive: $CONSECUTIVE_ZERO_SESSIONS/$MAX_ZERO_SESSIONS)"

        if [[ $CONSECUTIVE_ZERO_SESSIONS -ge $MAX_ZERO_SESSIONS ]]; then
            log "ERROR: $MAX_ZERO_SESSIONS consecutive sessions with zero progress"
            log "Please check the session logs for errors:"
            log "  tail -100 $session_log"

            # Show last session errors if available
            if [[ $session_has_errors -eq 1 ]]; then
                log "Last session errors detected:"
                tail -20 "$session_log" | grep -E "(ERROR|WARNING|RangeError|heap)" || true
            fi

            error_exit "Aborting due to repeated zero progress"
        fi
    else
        # Reset counter on successful progress
        CONSECUTIVE_ZERO_SESSIONS=0
        log "✓ Progress detected, resetting zero-session counter"
    fi

    # If session had errors but made progress, warn but continue
    if [[ $session_has_errors -eq 1 ]] && [[ $entries_completed -gt 0 ]]; then
        log "⚠ Session had errors but made progress ($entries_completed entries)"
        log "  Continuing with caution - will use longer cooldown before next session"
    fi

    # Log session details
    log "Session log saved: $session_log"
    log ""

    # Return error status for main loop
    return $session_has_errors
}

# Main automation loop
main() {
    log "========================================="
    log "Wasteland 3 Retranslation Automation"
    log "========================================="
    log "Start time: $(date)"
    log "Progress file: $PROGRESS_FILE"
    log "Log file: $LOG_FILE"
    log ""

    # Acquire exclusive lock (prevent duplicate sessions)
    acquire_lock

    # Check prerequisites
    check_prerequisites

    # Check if already complete
    if is_retranslation_complete; then
        log "========================================="
        log "✅ RETRANSLATION COMPLETE!"
        log "========================================="
        log "All files have been retranslated successfully."
        log "Total entries: $(get_progress_stats)"
        log "End time: $(date)"
        exit 0
    fi

    # Main loop
    while true; do
        # Run Claude Code session
        set +e  # Don't exit on error from run_claude_session
        run_claude_session
        local session_had_errors=$?
        set -e

        # Check if complete
        if is_retranslation_complete; then
            log "========================================="
            log "✅ RETRANSLATION COMPLETE!"
            log "========================================="
            log "All files have been retranslated successfully."
            log "Total entries: $(get_progress_stats)"
            log "End time: $(date)"
            exit 0
        fi

        # Adaptive cooldown based on session health
        if [[ $session_had_errors -eq 1 ]]; then
            log "Cooldown: waiting 180 seconds (3 minutes) due to errors in previous session..."
            sleep 180
        else
            log "Cooldown: waiting 60 seconds before next session..."
            sleep 60
        fi
    done
}

# Parse command line arguments
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
        echo "  Or use: ./automation/unlock-retranslation.sh --force"
        exit 1
    else
        rm -f "$LOCK_FILE"
        echo "✓ Stale lock file removed"
        echo ""
        echo "You can now run: ./automation/auto-retranslate.sh"
        exit 0
    fi
fi

# Trap errors
trap 'error_exit "Script interrupted or failed"' ERR

# Run main function
main "$@"
