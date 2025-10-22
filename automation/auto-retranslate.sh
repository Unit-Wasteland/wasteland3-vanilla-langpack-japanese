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
#   ./automation/auto-retranslate.sh
#
# Requirements:
# - Claude Code CLI installed
# - English source files in translation/source/v1.6.9.420.309496/en_US/
# - Broken translations in translation/backup_broken/
# - Progress file: translation/.retranslation_progress.json
#
# Memory Management:
# - 4GB: Warning threshold (reduce chunk size)
# - 6GB: Mandatory session restart
# - Progress persisted in .retranslation_progress.json
#
# Safety Features:
# - 50-line chunk processing (never exceed 100 lines)
# - 100-entry commit frequency (reduce memory pressure)
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

**重要な処理パラメータ:**
- read_chunk_size: 50行（NEVER exceed 100 lines）
- batch_size: 50エントリ
- commit_frequency: 100エントリごと
- メモリ安全モード: 有効（4GB警告、6GB強制終了）

**構造保護（CRITICAL）:**
- 絶対に変更禁止: "" [] <> ' ::action::
- Script Node は翻訳禁止
- 行数は絶対に変更禁止

**処理戦略:**
1. backup_brokenから日本語テキストを抽出
2. 英語ファイルの構造を保持
3. テキスト部分のみ安全に置換
4. 未翻訳は英語→日本語に翻訳（nouns_glossary.json参照）
5. 100エントリごとにコミット

**検証（MANDATORY）:**
- 各エディット後に行数一致確認
- 構造マーカー破損チェック
- 中国語混入チェック

作業を開始してください。
EOF
}

# Run single Claude Code session
run_claude_session() {
    ((SESSION_COUNT++))
    local session_log="$SCRIPT_DIR/.session_${SESSION_COUNT}_output.log"

    log "========================================="
    log "Starting session #$SESSION_COUNT"
    log "========================================="

    # Get progress before session
    local progress_before
    progress_before=$(get_progress_stats)
    log "Progress before session: $progress_before entries completed"

    # Create command file
    create_claude_command

    # Run Claude Code with automatic permission approval
    log "Executing Claude Code session..."
    if yes | cat "$COMMAND_FILE" | claude --dangerously-skip-permissions > "$session_log" 2>&1; then
        log "Session #$SESSION_COUNT completed successfully"
    else
        log "WARNING: Session #$SESSION_COUNT exited with non-zero status (may be normal)"
    fi

    # Get progress after session
    local progress_after
    progress_after=$(get_progress_stats)
    local entries_completed=$((progress_after - progress_before))

    log "Progress after session: $progress_after entries completed"
    log "Entries completed this session: $entries_completed"

    # Check for zero progress
    if [[ $entries_completed -eq 0 ]]; then
        ((CONSECUTIVE_ZERO_SESSIONS++))
        log "WARNING: Zero entries completed (consecutive: $CONSECUTIVE_ZERO_SESSIONS/$MAX_ZERO_SESSIONS)"

        if [[ $CONSECUTIVE_ZERO_SESSIONS -ge $MAX_ZERO_SESSIONS ]]; then
            log "ERROR: $MAX_ZERO_SESSIONS consecutive sessions with zero progress"
            log "Please check the session logs for errors:"
            log "  tail -100 $session_log"
            error_exit "Aborting due to repeated zero progress"
        fi
    else
        # Reset counter on successful progress
        CONSECUTIVE_ZERO_SESSIONS=0
        log "✓ Progress detected, resetting zero-session counter"
    fi

    # Log session details
    log "Session log saved: $session_log"
    log ""
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
        run_claude_session

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

        # Wait before next session (cooldown)
        log "Cooldown: waiting 60 seconds before next session..."
        sleep 60
    done
}

# Trap errors
trap 'error_exit "Script interrupted or failed"' ERR

# Run main function
main "$@"
