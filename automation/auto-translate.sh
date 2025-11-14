#!/bin/bash
# Wasteland 3 Japanese Translation - Automated Translation Script (Bash version)
# This script runs Claude Code in a loop, automatically restarting sessions
# when memory usage gets too high or after completing a batch of entries.

set -e

# Configuration
MAX_MEMORY_MB=7000
ENTRIES_PER_SESSION=2500
MAX_SESSIONS=100
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
    cat > "$COMMAND_FILE" << 'EOF'
translation/.translation_progress.json を読み込んで、CLAUDE.mdおよびTRANSLATION_WORKFLOW.mdのルールに厳格に従って翻訳作業を継続してください。

⚠️ **自動実行モード - 重要な制約**:
- **サブエージェントは使用しない** - メインセッションで直接翻訳
- ファイル編集権限を含む全ての権限リクエストは自動承認
- ユーザーへの質問や確認なしで作業を進める

⚠️ **CRITICAL: CLAUDE.mdの厳格なルール - 絶対に遵守**:

1. **Unity StringTable形式の保持（最重要）**:
   - 通常のテキスト: `string data = ""日本語テキスト""`（ダブルダブルクォート）
   - 空文字列: `string data = ""`
   - **英語版の構造を完全に保持**: 英語版のダブルクォート数と完全一致させる
   - テキスト内に `"` がある場合、そのまま保持（エスケープしない）
   - **絶対禁止**: `\"` エスケープ、日本語括弧 `「」` `『』`、全角クォート `""` `''`

2. **::action:: マーカーの厳格な保持**:
   - **絶対に翻訳しない**: `::sigh::`, `::laughs::`, `::static::` など
   - 英語のまま文字単位で完全保持
   - 翻訳後、必ず検証: `grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE` → 出力なし = OK

3. **固有名詞の一貫性（必須）**:
   - **必ず nouns_glossary.json を参照**してから翻訳
   - 例: "Rangers" → "レンジャー"（"レンジャーズ"は誤り）
   - 例: "Patriarch" → "パトリアーク"

4. **do_not_translate リストの遵守**:
   - "Script Node", "[Global:]", "[Switch to]" などは翻訳しない
   - nouns_glossary.json の do_not_translate セクションを確認

5. **スペイン語版参照ルール**:
   - スペイン語版が翻訳されている → 日本語にも翻訳
   - スペイン語版が空 or 英語と同じ → do_not_translate リストを確認
     - リストにある → 翻訳しない
     - リストにない → 文脈で判断（通常は翻訳）

6. **翻訳手順（Edit tool必須、スクリプト禁止）**:
   - Readツールでファイル読み込み
   - nouns_glossary.json で固有名詞確認
   - Editツールで1エントリずつ翻訳（スクリプト一括処理は絶対禁止）
   - old_stringは英語版と完全一致させる
   - 行数を保持（530,425行）

7. **メモリ管理（6GB RAM環境）**:
   - 各Read/Edit操作: 最大200行
   - コミット頻度: 500エントリまたはセクション完了時（少ない方）
   - 大きなファイルは複数回のRead/Edit操作に分割

8. **処理順序（必須）**:
   - ファイルを先頭から順次処理
   - スキップ、優先順位付け、バッチ処理は禁止
   - セクション完了後、次のセクションへ

⚠️ **目標**: 約2500エントリを翻訳して、コミット・プッシュしてから進捗を報告

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
    # --dangerously-skip-permissions: Bypass all permission checks for automated execution
    # yes: Automatically answer 'y' to any interactive permission prompts
    timeout 3600 bash -c "yes | cat '$COMMAND_FILE' | claude --dangerously-skip-permissions" > "$OUTPUT_FILE" 2>&1 &
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
